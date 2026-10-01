import secrets
import time
from typing import Any, Dict, Optional
from urllib.parse import urlencode

import httpx
from fastapi import APIRouter, Request, Response, HTTPException, Depends
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session

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
    return bool(settings.GOOGLE_CLIENT_ID and settings.GOOGLE_CLIENT_SECRET)


def _safe_next_path(next_path: Optional[str]) -> str:
    if next_path and next_path.startswith("/") and not next_path.startswith("//"):
        return next_path
    return "/"


def _request_is_https(request: Request) -> bool:
    forwarded_scheme = request.headers.get("x-forwarded-proto", "").split(",", 1)[0].strip()
    return request.url.scheme == "https" or forwarded_scheme == "https"


def _prune_oauth_states() -> None:
    cutoff = time.time() - settings.GOOGLE_OAUTH_STATE_MAX_AGE
    for state, record in list(OAUTH_STATES.items()):
        if record["created_at"] < cutoff:
            OAUTH_STATES.pop(state, None)


def _set_session_cookie(response: Response, request: Request, user_dict: dict) -> None:
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
    user = get_current_user(request)
    if user:
        if user.get("role") == "admin":
            return RedirectResponse("/admin", status_code=303)
        return RedirectResponse("/get", status_code=303)
    lang = request.query_params.get("lang", "tg")
    name = f"auth_{lang}.html" if lang in ("ru", "en") else "auth.html"
    return templates.TemplateResponse(
        request=request, name=name, context={"app_version": settings.APP_VERSION, "lang": lang}
    )

@router.post("/api/auth/register")
def api_register(payload: UserRegister, request: Request, response: Response, db: Session = Depends(get_db)):
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

@router.get("/logout")
def logout(request: Request, response: Response):
    token = request.cookies.get(settings.SESSION_COOKIE_NAME)
    if token in SESSIONS:
        del SESSIONS[token]
    from app.core.security import SESSION_EXPIRY
    SESSION_EXPIRY.pop(token, None)
    response = RedirectResponse("/", status_code=303)
    response.delete_cookie(settings.SESSION_COOKIE_NAME)
    return response
