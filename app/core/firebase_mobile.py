"""Small Firebase ID-token bridge for the mobile REST API.

The mobile client still uses Firebase Authentication for sign-in, but all
family data is handled by our FastAPI/SQLAlchemy service. Token validation is
done by Google's Identity Toolkit API, so the server never trusts a UID sent
by the client and never needs Firebase Realtime Database permissions.
"""

from typing import Optional

import httpx
from fastapi import HTTPException, Request, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.user import User


def _bearer(request: Request) -> str:
    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase ID token лозим аст",
        )
    token = header[7:].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Firebase ID token холӣ аст")
    return token


def _lookup(token: str) -> dict:
    if not settings.FIREBASE_WEB_API_KEY:
        raise HTTPException(status_code=503, detail="Firebase token verification танзим нашудааст")
    url = (
        "https://identitytoolkit.googleapis.com/v1/accounts:lookup"
        f"?key={settings.FIREBASE_WEB_API_KEY}"
    )
    try:
        response = httpx.post(url, json={"idToken": token}, timeout=8.0)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail="Санҷиши сессия ҳоло дастнорас аст") from exc
    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="Сессияи Firebase нодуруст ё гузаштааст")
    try:
        users = response.json().get("users") or []
    except ValueError as exc:
        raise HTTPException(status_code=502, detail="Ҷавоби Firebase нодуруст аст") from exc
    if not users or not users[0].get("localId") or not users[0].get("email"):
        raise HTTPException(status_code=401, detail="Маълумоти корбар аз Firebase ёфт нашуд")
    user = users[0]
    return {
        "firebase_uid": str(user["localId"]),
        "email": str(user["email"]).strip().lower(),
        "full_name": str(user.get("displayName") or user["email"].split("@", 1)[0]),
        "avatar": user.get("photoUrl"),
    }


def require_firebase_user(request: Request, db: Session) -> dict:
    """Validate the bearer token and return the local SQLAlchemy user dict."""
    identity = _lookup(_bearer(request))
    user = db.query(User).filter(User.firebase_uid == identity["firebase_uid"]).first()
    if user is None:
        user = db.query(User).filter(User.email == identity["email"]).first()
    role_hint = request.headers.get("X-NIGOH-Role", "").strip().lower()
    if role_hint not in {"parent", "child"}:
        role_hint = "unassigned"
    if user is None:
        user = User(
            email=identity["email"],
            full_name=identity["full_name"],
            avatar=identity["avatar"],
            role=role_hint,
            firebase_uid=identity["firebase_uid"],
        )
        db.add(user)
    else:
        user.firebase_uid = identity["firebase_uid"]
        user.full_name = identity["full_name"] or user.full_name
        if identity["avatar"]:
            user.avatar = identity["avatar"]
        if user.role in (None, "", "unassigned") and role_hint != "unassigned":
            user.role = role_hint
    db.commit()
    db.refresh(user)
    return user.to_dict()


def find_user_by_firebase_uid(db: Session, firebase_uid: Optional[str]) -> Optional[User]:
    if not firebase_uid:
        return None
    return db.query(User).filter(User.firebase_uid == firebase_uid).first()
