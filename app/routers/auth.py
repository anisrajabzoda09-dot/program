"""Файл: бақайдгирӣ, воридшавӣ, баромадан ва OAuth-и website."""

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

from app.core import apple_auth, github_auth
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
    """Маълумоти ёрирасони Google configured-ро омода карда, ба caller бармегардонад."""

    return bool(settings.GOOGLE_CLIENT_ID and settings.GOOGLE_CLIENT_SECRET)


def _safe_next_path(next_path: Optional[str]) -> str:
    """Маълумоти ёрирасони бехатар next path-ро омода карда, ба caller бармегардонад."""

    if next_path and next_path.startswith("/") and not next_path.startswith("//"):
        return next_path
    return "/"


def _request_is_https(request: Request) -> bool:
    """Маълумоти ёрирасони дархост is https-ро омода карда, ба caller бармегардонад."""

    forwarded_scheme = request.headers.get("x-forwarded-proto", "").split(",", 1)[0].strip()
    return request.url.scheme == "https" or forwarded_scheme == "https"


def _prune_oauth_states() -> None:
    """prune OAuth states-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    cutoff = time.time() - settings.GOOGLE_OAUTH_STATE_MAX_AGE
    for state, record in list(OAUTH_STATES.items()):
        if record["created_at"] < cutoff:
            OAUTH_STATES.pop(state, None)


def _set_session_cookie(response: Response, request: Request, user_dict: dict) -> None:
    """set session cookie-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

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
    """Маълумоти ёрирасони Google userinfo from access token-ро омода карда, ба caller бармегардонад."""

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
    """Маълумоти ёрирасони exchange Google code-ро омода карда, ба caller бармегардонад."""

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
    """Маълумоти ёрирасони sign in Google корбар-ро омода карда, ба caller бармегардонад."""

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
    """Дархости `GET /auth`-ро барои auth саҳифа коркард мекунад."""

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
                 "apple_enabled": apple_auth.apple_configured(),
                 "github_enabled": github_auth.github_configured()},
    )

@router.post("/api/auth/register")
def api_register(payload: UserRegister, request: Request, response: Response, db: Session = Depends(get_db)):
    """Дархости `POST /api/auth/register`-ро барои register коркард мекунад."""

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
    """Дархости `POST /api/auth/login`-ро барои login коркард мекунад."""

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
    """Дархости `POST /api/auth/google`-ро барои Google auth коркард мекунад."""
    check_rate_limit(request, action="google", max_requests=10, window_seconds=60)
    userinfo = _google_userinfo_from_access_token(payload.token)
    user_dict = _sign_in_google_user(request, response, db, userinfo)
    return {"status": "success", "user": user_dict, "redirect": "/get"}


@router.get("/auth/google/login")
def google_login(request: Request, next: str = "/"):
    """Дархости `GET /auth/google/login`-ро барои Google login коркард мекунад."""

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
    """Дархости `GET /auth/google/callback`-ро барои Google callback коркард мекунад."""

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
    """Маълумоти ёрирасони Apple auth саҳифа-ро омода карда, ба caller бармегардонад."""
    query = f"apple={status}"
    return f"/auth?lang={lang}&{query}" if lang in ("ru", "en") else f"/auth?{query}"


@router.get("/auth/apple/login")
def apple_login(request: Request, next: str = "/", lang: str = "tg"):
    """Дархости `GET /auth/apple/login`-ро барои Apple login коркард мекунад."""
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
    """Дархости `POST /auth/apple/callback`-ро барои Apple callback коркард мекунад."""
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
    """Дархости `POST /auth/apple/android`-ро барои Apple android bridge коркард мекунад."""
    form = await request.form()
    allowed = {k: str(v) for k, v in form.items() if k in ("code", "id_token", "state", "user", "error")}
    target = (f"intent://callback?{urlencode(allowed)}#Intent;"
              f"package={settings.APPLE_ANDROID_PACKAGE};scheme=signinwithapple;end")
    return RedirectResponse(target, status_code=307)


GITHUB_STATE_COOKIE = "github_oauth_state"


def _github_auth_page(lang: str, status: str) -> str:
    """Маълумоти ёрирасони GitHub auth саҳифа-ро омода карда, ба caller бармегардонад."""
    return f"/auth?lang={lang}&github={status}" if lang in ("ru", "en") else f"/auth?github={status}"


def _github_redirect(request: Request, record: dict) -> RedirectResponse:
    """Маълумоти ёрирасони GitHub redirect-ро омода карда, ба caller бармегардонад."""
    _prune_oauth_states()
    state = secrets.token_urlsafe(32)
    OAUTH_STATES[state] = {"created_at": time.time(), "provider": "github", **record}
    params = {"client_id": settings.GITHUB_CLIENT_ID, "redirect_uri": settings.GITHUB_REDIRECT_URI,
              "scope": "read:user user:email", "state": state, "allow_signup": "true"}
    response = RedirectResponse(f"{settings.GITHUB_AUTHORIZATION_ENDPOINT}?{urlencode(params)}", status_code=307)
    response.set_cookie(key=GITHUB_STATE_COOKIE, value=state, httponly=True, samesite="lax",
                        secure=_request_is_https(request), max_age=settings.GOOGLE_OAUTH_STATE_MAX_AGE)
    return response


def _app_return(query: str) -> RedirectResponse:
    """Маълумоти ёрирасони app return-ро омода карда, ба caller бармегардонад."""
    return RedirectResponse(f"{settings.GITHUB_APP_SCHEME}://auth/github?{query}", status_code=303)


@router.get("/auth/github/login")
def github_login(request: Request, next: str = "/", lang: str = "tg"):
    """Дархости `GET /auth/github/login`-ро барои GitHub login коркард мекунад."""
    if not github_auth.github_configured():
        return RedirectResponse(_github_auth_page(lang, "not_configured"), status_code=303)
    return _github_redirect(request, {"next": _safe_next_path(next), "lang": lang, "mobile": False})


@router.get("/auth/github/mobile")
def github_mobile_start(request: Request, nonce_hash: str = ""):
    """Дархости `GET /auth/github/mobile`-ро барои GitHub start коркард мекунад."""
    if not github_auth.github_configured():
        return _app_return("error=not_configured")
    if len(nonce_hash) != 64 or any(ch not in "0123456789abcdef" for ch in nonce_hash):
        raise HTTPException(status_code=400, detail="Воридшавӣ бо GitHub тасдиқ нашуд")
    return _github_redirect(request, {"next": "/", "lang": "tg", "mobile": True, "nonce_hash": nonce_hash})


@router.get("/auth/github/callback")
def github_callback(
    request: Request,
    db: Session = Depends(get_db),
    code: Optional[str] = None,
    state: Optional[str] = None,
    error: Optional[str] = None,
):
    """Дархости `GET /auth/github/callback`-ро барои GitHub callback коркард мекунад."""
    _prune_oauth_states()
    record = OAUTH_STATES.pop(state, None) if state else None
    mobile = bool(record and record.get("mobile"))
    lang = (record or {}).get("lang", "tg")

    def fail(status: str) -> RedirectResponse:
        """Маълумоти ёрирасони fail-ро омода карда, ба caller бармегардонад."""
        return _app_return(f"error={status}") if mobile else RedirectResponse(_github_auth_page(lang, status), status_code=303)

    if error:
        return fail("cancelled")
    cookie = request.cookies.get(GITHUB_STATE_COOKIE)
    if (not code or not record or record.get("provider") != "github" or not cookie
            or not secrets.compare_digest(state, cookie)):
        return fail("failed")
    try:
        identity = github_auth.fetch_identity(code)
    except HTTPException as exc:
        return fail("no_email" if exc.status_code == 400 else "failed")
    account = github_auth.upsert_github_user(db, identity)
    if mobile:
        response = _app_return("ticket=" + github_auth.issue_ticket(account.id, record["nonce_hash"]))
    else:
        response = RedirectResponse(record["next"], status_code=303)
        _set_session_cookie(response, request, account.to_dict())
    response.delete_cookie(GITHUB_STATE_COOKIE)
    return response


@router.get("/logout")
def logout(request: Request, response: Response):
    """Дархости `GET /logout`-ро барои logout коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    token = request.cookies.get(settings.SESSION_COOKIE_NAME)
    if token in SESSIONS:
        del SESSIONS[token]
    from app.core.security import SESSION_EXPIRY
    SESSION_EXPIRY.pop(token, None)
    response = RedirectResponse("/", status_code=303)
    response.delete_cookie(settings.SESSION_COOKIE_NAME)
    return response
