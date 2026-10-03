"""Authentication for the NIGOH Android app without Firebase.

The app signs in with email/password or a Google ID token and receives an
opaque bearer token (``ngh_…``). Only its SHA-256 hash is stored, so a database
leak does not expose usable tokens. Tokens from older Firebase-based builds are
still accepted during the transition.
"""

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx
from fastapi import HTTPException, Request
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.mobile_session import MobileSession
from app.models.user import User

TOKEN_PREFIX = "ngh_"
SESSION_TTL = timedelta(days=180)
_ROLES = {"parent", "child"}


def _hash(token: str) -> str:
    """Create the irreversible token digest stored for a mobile session."""

    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue_token(db: Session, user: User, device: str = "") -> str:
    """Create and persist a mobile session, returning its bearer token."""

    token = TOKEN_PREFIX + secrets.token_urlsafe(32)
    db.add(MobileSession(user_id=user.id, token_hash=_hash(token), device=(device or "")[:160]))
    db.commit()
    return token


def revoke_token(db: Session, token: str) -> None:
    """Delete the session represented by a bearer token from the database."""

    db.query(MobileSession).filter(MobileSession.token_hash == _hash(token)).delete()
    db.commit()


def bearer_token(request: Request) -> str:
    """Read a required bearer token from an incoming mobile request."""

    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer ") or not header[7:].strip():
        raise HTTPException(status_code=401, detail="Лутфан аз нав ворид шавед")
    return header[7:].strip()


def _role_hint(request: Request) -> Optional[str]:
    """Return a valid per-device family role hint from request headers."""

    hint = request.headers.get("X-NIGOH-Role", "").strip().lower()
    return hint if hint in _ROLES else None


def _user_dict(user: User, request: Request) -> dict:
    """Serialize a user with the requesting device's effective family role."""

    data = user.to_dict()
    hint = _role_hint(request)
    # The role chosen on this phone decides which family side the request acts
    # for. One Google account may be a parent on one phone and a child on
    # another; a stored role must never lock it out (this caused 403s).
    if hint and user.role != "admin":
        data["role"] = hint
    return data


def _session_user(db: Session, token: str) -> User:
    """Resolve an active session to its user and refresh recent activity."""

    session = db.query(MobileSession).filter(MobileSession.token_hash == _hash(token)).first()
    if session is None:
        raise HTTPException(status_code=401, detail="Сессия ба охир расид. Аз нав ворид шавед")
    now = datetime.utcnow()
    created = session.created_at or now
    if now - created > SESSION_TTL:
        db.delete(session)
        db.commit()
        raise HTTPException(status_code=401, detail="Сессия ба охир расид. Аз нав ворид шавед")
    user = db.query(User).filter(User.id == session.user_id).first()
    if user is None:
        raise HTTPException(status_code=401, detail="Ҳисоб ёфт нашуд")
    if session.last_seen_at is None or now - session.last_seen_at > timedelta(minutes=5):
        session.last_seen_at = now
        db.commit()
    return user


def require_mobile_user(request: Request, db: Session) -> dict:
    """Resolve the signed-in app user from a NIGOH token (or a legacy Firebase token)."""
    token = bearer_token(request)
    if token.startswith(TOKEN_PREFIX):
        user = _session_user(db, token)
    else:
        from app.core.firebase_mobile import require_firebase_user  # legacy builds

        legacy = require_firebase_user(request, db)
        user = db.query(User).filter(User.id == legacy["id"]).first()
    hint = _role_hint(request)
    if hint and user.role in (None, "", "unassigned"):
        user.role = hint
        db.commit()
    return _user_dict(user, request)


# ---------- Google ----------

def _allowed_google_audiences() -> set:
    """Parse the configured OAuth client IDs accepted from mobile clients."""

    raw = settings.GOOGLE_MOBILE_CLIENT_IDS
    return {item.strip() for item in raw.split(",") if item.strip()}


def verify_google_id_token(id_token: str) -> dict:
    """Verify a Google ID token and return normalized account identity data."""

    try:
        response = httpx.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": id_token},
            timeout=8.0,
        )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail="Google ҳоло дастнорас аст. Баъдтар кӯшиш кунед") from exc
    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="Воридшавӣ бо Google тасдиқ нашуд")
    info = response.json()
    if info.get("aud") not in _allowed_google_audiences():
        raise HTTPException(status_code=401, detail="Ин барнома барои Google тасдиқ нашудааст")
    if info.get("iss") not in ("accounts.google.com", "https://accounts.google.com"):
        raise HTTPException(status_code=401, detail="Воридшавӣ бо Google тасдиқ нашуд")
    if str(info.get("email_verified")).lower() != "true" or not info.get("email"):
        raise HTTPException(status_code=401, detail="Почтаи Google тасдиқ нашудааст")
    return {
        "google_id": str(info.get("sub")),
        "email": str(info["email"]).strip().lower(),
        "full_name": str(info.get("name") or info["email"].split("@", 1)[0]),
        "avatar": info.get("picture"),
    }


def upsert_google_user(db: Session, identity: dict) -> User:
    """Create or refresh the local account for a verified Google identity."""

    user = db.query(User).filter(User.google_id == identity["google_id"]).first()
    if user is None:
        user = db.query(User).filter(User.email == identity["email"]).first()
    if user is None:
        user = User(
            email=identity["email"],
            full_name=identity["full_name"],
            avatar=identity["avatar"],
            google_id=identity["google_id"],
            role="unassigned",
        )
        db.add(user)
    else:
        user.google_id = identity["google_id"]
        user.avatar = identity["avatar"] or user.avatar
        user.full_name = user.full_name or identity["full_name"]
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        user = db.query(User).filter(User.email == identity["email"]).first()
        if user is None:
            raise HTTPException(status_code=409, detail="Ҳисоб сохта нашуд. Аз нав кӯшиш кунед")
    db.refresh(user)
    return user
