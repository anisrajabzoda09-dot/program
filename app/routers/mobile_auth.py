"""Файл: endpoint-ҳои воридшавӣ ва профили app-и Android."""

import base64
import os
import secrets
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.mobile_auth import (
    bearer_token,
    issue_token,
    require_mobile_user,
    revoke_token,
    upsert_google_user,
    verify_google_id_token,
)
from app.core import apple_auth, github_auth, otp
from app.core.i18n import request_lang
from app.core.config import settings
from app.core.security import check_rate_limit, hash_password, verify_password
from app.db.session import get_db
from app.models.user import User

router = APIRouter(prefix="/api/mobile/v3", tags=["Mobile auth"])


class RegisterRequest(BaseModel):
    """Маълумоти `RegisterRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    email: str = Field(..., min_length=3, max_length=254)
    password: str = Field(..., min_length=8, max_length=128)
    full_name: str = Field(..., min_length=1, max_length=120)


class LoginRequest(BaseModel):
    """Маълумоти `LoginRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    email: str = Field(..., min_length=1, max_length=254)
    password: str = Field(..., min_length=1, max_length=128)


class GoogleRequest(BaseModel):
    """Маълумоти `GoogleRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    id_token: str = Field(..., min_length=20)


class ProfileUpdate(BaseModel):
    """Маълумоти `ProfileUpdate`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    full_name: Optional[str] = Field(default=None, min_length=1, max_length=120)
    role: Optional[str] = Field(default=None, pattern="^(parent|child)$")


def _device(request: Request) -> str:
    """Маълумоти ёрирасони дастгоҳ-ро омода карда, ба caller бармегардонад."""

    return request.headers.get("X-NIGOH-Device") or request.headers.get("user-agent", "")


def _auth_response(db: Session, user: User, request: Request) -> dict:
    """Маълумоти ёрирасони auth response-ро омода карда, ба caller бармегардонад."""

    return {
        "status": "success",
        "token": issue_token(db, user, _device(request)),
        "user": {
            "id": user.id,
            "email": user.email,
            "full_name": user.full_name,
            "avatar": user.avatar,
            "role": user.role if user.role in ("parent", "child") else None,
        },
    }


@router.post("/auth/register")
def register(payload: RegisterRequest, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /auth/register`-ро барои register коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    check_rate_limit(request, "mobile_register", max_requests=10, window_seconds=600)
    email = payload.email.strip().lower()
    if "@" not in email or "." not in email.split("@")[-1]:
        raise HTTPException(status_code=400, detail="Почтаи электронӣ нодуруст аст")
    if db.query(User).filter(User.email == email).first():
        raise HTTPException(status_code=400, detail="Ин почта аллакай сабт шудааст. Ворид шавед")
    user = User(
        email=email,
        full_name=payload.full_name.strip(),
        password_hash=hash_password(payload.password),
        role="unassigned",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return _auth_response(db, user, request)


@router.post("/auth/login")
def login(payload: LoginRequest, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /auth/login`-ро барои login коркард мекунад."""

    check_rate_limit(request, "mobile_login", max_requests=20, window_seconds=300)
    user = db.query(User).filter(User.email == payload.email.strip().lower()).first()
    if user is None or not user.password_hash:
        raise HTTPException(status_code=400, detail="Почта ё рамз нодуруст аст")
    # Қулфи ҳисоб пас аз 5 кӯшиши нодуруст (ҳамон ҳисобкунаки сайт ва OTP).
    try:
        otp.check_not_locked(user)
    except otp.OtpError as error:
        raise HTTPException(status_code=429, detail=otp.message(error, request_lang(request.headers)))
    if not verify_password(payload.password, user.password_hash):
        otp.register_failure(db, user)
        raise HTTPException(status_code=400, detail="Почта ё рамз нодуруст аст")
    if user.role == "admin":
        raise HTTPException(status_code=403, detail="Ҳисоби админ барои барнома нест")
    otp.reset_failures(user)
    if not user.password_hash.startswith("scrypt$"):
        user.password_hash = hash_password(payload.password)
    db.commit()
    # Бо Authenticator барнома аввал чипта мегирад, баъд рамзро мефиристад.
    if otp.needs_second_factor(user):
        return {"status": "otp_required", "ticket": otp.issue_ticket(user)}
    return _auth_response(db, user, request)


@router.post("/auth/google")
def google(payload: GoogleRequest, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /auth/google`-ро барои Google коркард мекунад."""

    check_rate_limit(request, "mobile_google", max_requests=20, window_seconds=300)
    user = upsert_google_user(db, verify_google_id_token(payload.id_token))
    if user.role == "admin":
        raise HTTPException(status_code=403, detail="Ҳисоби админ барои барнома нест")
    return _auth_response(db, user, request)


@router.get("/auth/apple/config")
def apple_config():
    """Дархости `GET /auth/apple/config`-ро барои Apple танзимот коркард мекунад."""
    enabled = apple_auth.apple_configured()
    return {
        "enabled": enabled,
        "client_id": settings.APPLE_CLIENT_ID if enabled else None,
        "redirect_uri": settings.APPLE_REDIRECT_URI.rsplit("/", 1)[0] + "/android" if enabled else None,
    }


class AppleRequest(BaseModel):
    """Маълумоти `AppleRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    identity_token: str = Field(..., min_length=20)
    nonce: str = Field(..., min_length=16, max_length=128)
    full_name: Optional[str] = Field(None, max_length=120)


@router.post("/auth/apple")
def apple(payload: AppleRequest, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /auth/apple`-ро барои Apple коркард мекунад."""
    check_rate_limit(request, "mobile_apple", max_requests=20, window_seconds=300)
    if not apple_auth.apple_configured():
        raise HTTPException(status_code=503, detail="Sign in with Apple дар сервер танзим нашудааст")
    claims = apple_auth.verify_identity_token(payload.identity_token, apple_auth.apple_audiences(),
                                              nonce=payload.nonce)
    user = apple_auth.upsert_apple_user(db, claims, payload.full_name)
    if user.role == "admin":
        raise HTTPException(status_code=403, detail="Ҳисоби админ барои барнома нест")
    return _auth_response(db, user, request)


@router.get("/auth/github/config")
def github_config():
    """Дархости `GET /auth/github/config`-ро барои GitHub танзимот коркард мекунад."""
    enabled = github_auth.github_configured()
    base = settings.GITHUB_REDIRECT_URI.rsplit("/", 1)[0]
    return {"enabled": enabled,
            "start_url": f"{base}/mobile" if enabled else None,
            "callback_scheme": settings.GITHUB_APP_SCHEME if enabled else None}


class GitHubRequest(BaseModel):
    """Маълумоти `GitHubRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    ticket: str = Field(..., min_length=20, max_length=128)
    nonce: str = Field(..., min_length=16, max_length=128)


@router.post("/auth/github")
def github(payload: GitHubRequest, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /auth/github`-ро барои GitHub коркард мекунад."""
    check_rate_limit(request, "mobile_github", max_requests=20, window_seconds=300)
    user_id = github_auth.redeem_ticket(payload.ticket, payload.nonce)
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=401, detail="Воридшавӣ бо GitHub тасдиқ нашуд")
    if user.role == "admin":
        raise HTTPException(status_code=403, detail="Ҳисоби админ барои барнома нест")
    return _auth_response(db, user, request)


@router.post("/auth/logout")
def logout(request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /auth/logout`-ро барои logout коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    revoke_token(db, bearer_token(request))
    return {"status": "success"}


@router.get("/me")
def me(request: Request, db: Session = Depends(get_db)):
    """Дархости `GET /me`-ро барои me коркард мекунад."""

    user = require_mobile_user(request, db)
    return {"status": "success", "user": user}


@router.put("/me")
def update_me(payload: ProfileUpdate, request: Request, db: Session = Depends(get_db)):
    """Дархости `PUT /me`-ро барои update me коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    current = require_mobile_user(request, db)
    user = db.query(User).filter(User.id == current["id"]).first()
    if payload.full_name:
        user.full_name = payload.full_name.strip()
    if payload.role and user.role != "admin":
        user.role = payload.role
    db.commit()
    db.refresh(user)
    return {"status": "success", "user": user.to_dict()}


class AvatarUpload(BaseModel):
    """Маълумоти `AvatarUpload`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    # JPEG/PNG, already resized on the phone (≈512 px); ~350 KB of base64 max.
    image_base64: str = Field(..., min_length=100, max_length=480_000)


_AVATAR_DIR = os.path.join(settings.STATIC_DIR, "avatars")


@router.post("/me/avatar")
def upload_avatar(payload: AvatarUpload, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /me/avatar`-ро барои upload avatar коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""
    current = require_mobile_user(request, db)
    try:
        raw = base64.b64decode(payload.image_base64.split(",")[-1], validate=True)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Сурат вайрон аст")
    if raw[:3] == b"\xff\xd8\xff":
        ext = "jpg"
    elif raw[:8] == b"\x89PNG\r\n\x1a\n":
        ext = "png"
    else:
        raise HTTPException(status_code=400, detail="Танҳо сурати JPEG ё PNG")
    os.makedirs(_AVATAR_DIR, exist_ok=True)
    user = db.query(User).filter(User.id == current["id"]).first()
    old = user.avatar or ""
    name = f"{user.id}_{secrets.token_hex(8)}.{ext}"
    with open(os.path.join(_AVATAR_DIR, name), "wb") as fh:
        fh.write(raw)
    user.avatar = f"/static/avatars/{name}"
    db.commit()
    if old.startswith("/static/avatars/"):
        try:
            os.remove(os.path.join(_AVATAR_DIR, os.path.basename(old)))
        except OSError:
            pass
    return {"status": "success", "avatar": user.avatar}


@router.delete("/me/avatar")
def delete_avatar(request: Request, db: Session = Depends(get_db)):
    """Дархости `DELETE /me/avatar`-ро барои delete avatar коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    current = require_mobile_user(request, db)
    user = db.query(User).filter(User.id == current["id"]).first()
    old = user.avatar or ""
    user.avatar = None
    db.commit()
    if old.startswith("/static/avatars/"):
        try:
            os.remove(os.path.join(_AVATAR_DIR, os.path.basename(old)))
        except OSError:
            pass
    return {"status": "success"}
