"""Handle browser registration, login, logout, and Google / Apple OAuth sessions."""

import json
import secrets
import time
from typing import Any, Dict, Optional
from urllib.parse import urlencode

import httpx
from fastapi import APIRouter, Request, Response, HTTPException, Depends, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session

from app.core import apple_auth
from app.core.config import settings
from app.core.security import (
    create_session,
    get_current_user,
    verify_password,
    check_rate_limit,
    SESSIONS
)
from app.db.session import get_db
from app.schemas.auth import UserRegister, UserLogin, GoogleAuthRequest
from app.crud.crud_user import get_user_by_email, create_user, upsert_google_user

router = APIRouter(tags=["Authentication"])
templates = Jinja2Templates(directory=settings.TEMPLATES_DIR)

OAUTH_STATES: Dict[str, Dict[str, Any]] = {}


def _google_configured() -> bool:
    """Report whether both credentials needed for browser Google OAuth exist."""

    return bool(settings.GOOGLE_CLIENT_ID and settings.GOOGLE_CLIENT_SECRET)


def _safe_next_path(next_path: Optional[str]) -> str:
    """Accept only local redirect paths to prevent open redirects."""

    if next_path and next_path.startswith("/") and not next_path.startswith("//"):
        return next_path
    return "/"


def _request_is_https(request: Request) -> bool:
    """Detect HTTPS directly or through a trusted reverse-proxy header."""

    forwarded_scheme = request.headers.get("x-forwarded-proto", "").split(",", 1)[0].strip()
    return request.url.scheme == "https" or forwarded_scheme == "https"


def _prune_oauth_states() -> None:
    """Discard expired one-time OAuth state records from memory."""

    cutoff = time.time() - settings.GOOGLE_OAUTH_STATE_MAX_AGE
    for state, record in list(OAUTH_STATES.items()):
        if record["created_at"] < cutoff:
            OAUTH_STATES.pop(state, None)


def _set_session_cookie(response: Response, request: Request, user_dict: dict) -> None:
    """Create a web session and attach its protected cookie to a response."""

    token = create_session(user_dict)
    response.set_cookie(
        key=settings.SESSION_COOKIE_NAME,
        value=token,
        httponly=True,
        samesite="lax",
        max_age=settings.SESSION_MAX_AGE,
        secure=_request_is_https(request),
    )


def _google_userinfo_from_access_token(access_token: str) -> dict:
    """Fetch and validate the Google profile represented by an access token."""

    try:
        with httpx.Client(timeout=10.0) as client:
            result = client.get(
                settings.GOOGLE_USERINFO_ENDPOINT,
                headers={"Authorization": f"Bearer {access_token}"},
            )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail="Пайвастшавӣ ба Google муваффақ нашуд") from exc

    if result.status_code != 200:
        raise HTTPException(status_code=401, detail="Токени Google нодуруст ё гузаштааст")
    try:
        userinfo = result.json()
    except ValueError as exc:
        raise HTTPException(status_code=502, detail="Google маълумоти нодуруст баргардонд") from exc
    if not userinfo.get("sub") or not userinfo.get("email"):
        raise HTTPException(status_code=401, detail="Маълумоти тасдиқшудаи Google ёфт нашуд")
    if userinfo.get("email_verified") is False:
        raise HTTPException(status_code=403, detail="Почтаи Google тасдиқ нашудааст")
    return userinfo


def _exchange_google_code(code: str) -> dict:
    """Exchange an OAuth authorization code and return verified Google profile data."""

    try:
        with httpx.Client(timeout=10.0) as client:
            token_result = client.post(
                settings.GOOGLE_TOKEN_ENDPOINT,
                data={
                    "code": code,
                    "client_id": settings.GOOGLE_CLIENT_ID,
                    "client_secret": settings.GOOGLE_CLIENT_SECRET,
                    "redirect_uri": settings.GOOGLE_REDIRECT_URI,
                    "grant_type": "authorization_code",
                },
            )
            if token_result.status_code != 200:
                raise HTTPException(status_code=401, detail="Google code қабул карда нашуд")
            try:
                token_data = token_result.json()
            except ValueError as exc:
                raise HTTPException(status_code=502, detail="Google token response нодуруст аст") from exc
            access_token = token_data.get("access_token")
            if not access_token:
                raise HTTPException(status_code=401, detail="Google access token дастрас нест")
            return _google_userinfo_from_access_token(access_token)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail="Пайвастшавӣ ба Google муваффақ нашуд") from exc


def _sign_in_google_user(request: Request, response: Response, db: Session, userinfo: dict) -> dict:
    """Upsert a Google-backed account and establish its browser session."""

    user_obj = upsert_google_user(
        db=db,
        email=userinfo["email"],
        full_name=userinfo.get("name") or userinfo["email"].split("@", 1)[0],
        avatar=userinfo.get("picture"),
        google_id=userinfo["sub"],
    )
    user_dict = user_obj.to_dict()
    _set_session_cookie(response, request, user_dict)
    return user_dict

@router.get("/auth", response_class=HTMLResponse)
def auth_page(request: Request):
    """Render the localized sign-in page or redirect an existing session."""

    user = get_current_user(request)
    if user:
        if user.get("role") == "admin":
            return RedirectResponse("/admin", status_code=303)
        return RedirectResponse("/get", status_code=303)
    lang = request.query_params.get("lang", "tg")
    name = f"auth_{lang}.html" if lang in ("ru", "en") else "auth.html"
    return templates.TemplateResponse(
        request=request, name=name,
        context={"app_version": settings.APP_VERSION, "lang": lang,
                 "apple_enabled": apple_auth.apple_configured()},
    )

@router.post("/api/auth/register")
def api_register(payload: UserRegister, request: Request, response: Response, db: Session = Depends(get_db)):
    """Register a parent account and start an authenticated browser session."""

    # Rate limit registration attempts to mitigate spam bots
    check_rate_limit(request, action="register", max_requests=10, window_seconds=60)

    clean_email = payload.email.strip().lower()
    existing = get_user_by_email(db, clean_email)
    if existing:
        raise HTTPException(status_code=400, detail="Ин почтаи электронӣ аллакай ба қайд гирифта шудааст")

    user_obj = create_user(
        db=db,
        email=clean_email,
        password=payload.password,
        full_name=payload.full_name,
        role="parent"
    )
    user_dict = user_obj.to_dict()

    token = create_session(user_dict)
    response.set_cookie(
        key=settings.SESSION_COOKIE_NAME,
        value=token,
        httponly=True,
        samesite="lax",
        max_age=settings.SESSION_MAX_AGE,
        secure=_request_is_https(request)
    )
    return {"status": "success", "user": user_dict, "redirect": "/get"}

@router.post("/api/auth/login")
def api_login(payload: UserLogin, request: Request, response: Response, db: Session = Depends(get_db)):
    """Verify local credentials and start a rate-limited browser session."""

    # Anti brute-force protection
    check_rate_limit(request, action="login", max_requests=15, window_seconds=60)

    clean_email = payload.email.strip()
    user_obj = get_user_by_email(db, clean_email)
    if not user_obj or not user_obj.password_hash:
        raise HTTPException(status_code=400, detail="Почта ё пароли нодуруст")

    if not verify_password(payload.password, user_obj.password_hash):
        raise HTTPException(status_code=400, detail="Почта ё пароли нодуруст")

    user_dict = user_obj.to_dict()
    token = create_session(user_dict)
    response.set_cookie(
        key=settings.SESSION_COOKIE_NAME,
        value=token,
        httponly=True,
        samesite="lax",
        max_age=settings.SESSION_MAX_AGE,
        secure=_request_is_https(request)
    )

    redirect_target = "/admin" if user_dict.get("role") == "admin" else "/get"
    return {"status": "success", "user": user_dict, "redirect": redirect_target}

@router.post("/api/auth/google")
def api_google_auth(payload: GoogleAuthRequest, request: Request, response: Response, db: Session = Depends(get_db)):
    """Exchange a real Google access token for a NIGOH session.

    The browser OAuth flow uses ``/auth/google/callback``; this endpoint remains
    for trusted mobile clients that already completed Google sign-in.
    """
    check_rate_limit(request, action="google", max_requests=10, window_seconds=60)
    userinfo = _google_userinfo_from_access_token(payload.token)
    user_dict = _sign_in_google_user(request, response, db, userinfo)
    return {"status": "success", "user": user_dict, "redirect": "/get"}


@router.get("/auth/google/login")
def google_login(request: Request, next: str = "/"):
    """Start browser OAuth with a short-lived state and safe return path."""

    if not _google_configured():
        return RedirectResponse("/auth?google=not_configured", status_code=303)

    _prune_oauth_states()
    state = secrets.token_urlsafe(32)
    OAUTH_STATES[state] = {
        "created_at": time.time(),
        "next": _safe_next_path(next),
    }
    params = {
        "client_id": settings.GOOGLE_CLIENT_ID,
        "redirect_uri": settings.GOOGLE_REDIRECT_URI,
        "response_type": "code",
        "scope": settings.GOOGLE_OAUTH_SCOPES,
        "state": state,
        "access_type": "online",
        "include_granted_scopes": "true",
        "prompt": "select_account",
    }
    response = RedirectResponse(
        f"{settings.GOOGLE_AUTHORIZATION_ENDPOINT}?{urlencode(params)}",
        status_code=307,
    )
    response.set_cookie(
        key="google_oauth_state",
        value=state,
        httponly=True,
        secure=_request_is_https(request),
        samesite="lax",
        max_age=settings.GOOGLE_OAUTH_STATE_MAX_AGE,
    )
    return response


@router.get("/auth/google/callback")
def google_callback(
    request: Request,
    db: Session = Depends(get_db),
    code: Optional[str] = None,
    state: Optional[str] = None,
    error: Optional[str] = None,
):
    """Validate the OAuth callback, sign in the user, and redirect safely."""

    if error:
        return RedirectResponse("/auth?google=cancelled", status_code=303)
    if not code or not state:
        raise HTTPException(status_code=400, detail="Google OAuth code ё state вуҷуд надорад")

    _prune_oauth_states()
    state_cookie = request.cookies.get("google_oauth_state")
    state_record = OAUTH_STATES.pop(state, None)
    if not state_record or not state_cookie or not secrets.compare_digest(state, state_cookie):
        raise HTTPException(status_code=400, detail="Google OAuth state нодуруст ё гузаштааст")

    userinfo = _exchange_google_code(code)
    redirect_target = state_record["next"]
    user_response = RedirectResponse(redirect_target, status_code=303)
    _sign_in_google_user(request, user_response, db, userinfo)
    user_response.delete_cookie("google_oauth_state")
    return user_response

APPLE_STATE_COOKIE = "apple_oauth_state"


def _apple_auth_page(lang: str, status: str) -> str:
    """URL of the sign-in page in the visitor's language with an Apple status flag."""
    query = f"apple={status}"
    return f"/auth?lang={lang}&{query}" if lang in ("ru", "en") else f"/auth?{query}"


@router.get("/auth/apple/login")
def apple_login(request: Request, next: str = "/", lang: str = "tg"):
    """Start Sign in with Apple: remember a one-time state + nonce and redirect to Apple."""
    if not apple_auth.apple_configured():
        return RedirectResponse(_apple_auth_page(lang, "not_configured"), status_code=303)
    _prune_oauth_states()
    state = secrets.token_urlsafe(32)
    nonce = secrets.token_urlsafe(24)
    OAUTH_STATES[state] = {"created_at": time.time(), "next": _safe_next_path(next),
                           "nonce": nonce, "lang": lang, "provider": "apple"}
    params = {"client_id": settings.APPLE_CLIENT_ID, "redirect_uri": settings.APPLE_REDIRECT_URI,
              "response_type": "code", "response_mode": "form_post", "scope": "name email",
              "state": state, "nonce": nonce}
    response = RedirectResponse(f"{settings.APPLE_AUTHORIZATION_ENDPOINT}?{urlencode(params)}",
                                status_code=307)
    # Apple returns with a cross-site POST, so the state cookie must be
    # SameSite=None (which browsers only accept together with Secure).
    response.set_cookie(key=APPLE_STATE_COOKIE, value=state, httponly=True, secure=True,
                        samesite="none", max_age=settings.GOOGLE_OAUTH_STATE_MAX_AGE)
    return response


@router.post("/auth/apple/callback")
def apple_callback(
    request: Request,
    db: Session = Depends(get_db),
    code: Optional[str] = Form(None),
    state: Optional[str] = Form(None),
    user: Optional[str] = Form(None),
    error: Optional[str] = Form(None),
):
    """Finish the web flow: check state, exchange the code, verify the token, sign the user in."""
    _prune_oauth_states()
    record = OAUTH_STATES.pop(state, None) if state else None
    lang = (record or {}).get("lang", "tg")
    if error:
        return RedirectResponse(_apple_auth_page(lang, "cancelled"), status_code=303)
    cookie = request.cookies.get(APPLE_STATE_COOKIE)
    if (not code or not record or record.get("provider") != "apple" or not cookie
            or not secrets.compare_digest(state, cookie)):
        return RedirectResponse(_apple_auth_page(lang, "failed"), status_code=303)
    try:
        id_token = apple_auth.exchange_code(code, settings.APPLE_REDIRECT_URI)
        claims = apple_auth.verify_identity_token(id_token, [settings.APPLE_CLIENT_ID], nonce=record["nonce"])
    except HTTPException:
        return RedirectResponse(_apple_auth_page(lang, "failed"), status_code=303)
    full_name = None
    if user:  # Apple sends {"name": {"firstName", "lastName"}} only on the first sign-in.
        try:
            name = json.loads(user).get("name") or {}
            full_name = " ".join(p for p in (name.get("firstName"), name.get("lastName")) if p) or None
        except (ValueError, AttributeError):
            full_name = None
    account = apple_auth.upsert_apple_user(db, claims, full_name)
    response = RedirectResponse(record["next"], status_code=303)
    _set_session_cookie(response, request, account.to_dict())
    response.delete_cookie(APPLE_STATE_COOKIE, secure=True, samesite="none")
    return response


@router.post("/auth/apple/android")
async def apple_android_bridge(request: Request):
    """Hand Apple's form_post result back to the Android app (Sign in with Apple web flow).

    The Android plugin opens Apple in a browser tab with this URL as redirect;
    we bounce the posted fields to the app through an intent:// link for our
    package only. The app then sends the identity token to the mobile API.
    """
    form = await request.form()
    allowed = {k: str(v) for k, v in form.items() if k in ("code", "id_token", "state", "user", "error")}
    target = (f"intent://callback?{urlencode(allowed)}#Intent;"
              f"package={settings.APPLE_ANDROID_PACKAGE};scheme=signinwithapple;end")
    return RedirectResponse(target, status_code=307)


@router.get("/logout")
def logout(request: Request, response: Response):
    """Remove the active in-memory session and clear its browser cookie."""

    token = request.cookies.get(settings.SESSION_COOKIE_NAME)
    if token in SESSIONS:
        del SESSIONS[token]
    from app.core.security import SESSION_EXPIRY
    SESSION_EXPIRY.pop(token, None)
    response = RedirectResponse("/", status_code=303)
    response.delete_cookie(settings.SESSION_COOKIE_NAME)
    return response
