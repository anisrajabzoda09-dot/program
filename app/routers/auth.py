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

@router.get("/auth", response_class=HTMLResponse)
def auth_page(request: Request):
    user = get_current_user(request)
    if user:
        if user.get("role") == "admin":
            return RedirectResponse("/admin", status_code=303)
        return RedirectResponse("/#download", status_code=303)
    return templates.TemplateResponse(request=request, name="auth.html", context={})

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
        secure=request.url.scheme == "https"
    )
    return {"status": "success", "user": user_dict, "redirect": "/#download"}

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
        secure=request.url.scheme == "https"
    )

    redirect_target = "/admin" if user_dict.get("role") == "admin" else "/#download"
    return {"status": "success", "user": user_dict, "redirect": redirect_target}

@router.post("/api/auth/google")
def api_google_auth(payload: GoogleAuthRequest, request: Request, response: Response, db: Session = Depends(get_db)):
    """Google OAuth Sign-In"""
    user_obj = upsert_google_user(
        db=db,
        email=payload.email,
        full_name=payload.full_name,
        avatar=payload.avatar,
        google_id=payload.google_id
    )
    user_dict = user_obj.to_dict()

    token = create_session(user_dict)
    response.set_cookie(
        key=settings.SESSION_COOKIE_NAME,
        value=token,
        httponly=True,
        samesite="lax",
        max_age=settings.SESSION_MAX_AGE,
        secure=request.url.scheme == "https"
    )
    return {"status": "success", "user": user_dict, "redirect": "/#download"}

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
