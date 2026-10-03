"""Файл: воридшавӣ бо Apple, санҷиши token ва пайваст кардани ҳисоб."""

import hashlib
import time
from pathlib import Path
from typing import Iterable, Optional

import httpx
import jwt
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.user import User

# Cached JWKS client: Apple rotates keys rarely; PyJWKClient refetches on unknown kid.
_JWKS: Optional[jwt.PyJWKClient] = None


def apple_private_key() -> str:
    """Калиди хусусии .p8-и Apple-ро аз танзимот ё файл мехонад."""
    if settings.APPLE_PRIVATE_KEY.strip():
        return settings.APPLE_PRIVATE_KEY
    if settings.APPLE_PRIVATE_KEY_PATH and Path(settings.APPLE_PRIVATE_KEY_PATH).is_file():
        return Path(settings.APPLE_PRIVATE_KEY_PATH).read_text(encoding="utf-8")
    return ""


def apple_configured() -> bool:
    """Мавҷуд будани ҳамаи танзимоти Sign in with Apple-ро месанҷад."""
    return bool(settings.APPLE_CLIENT_ID and settings.APPLE_TEAM_ID and settings.APPLE_KEY_ID
                and apple_private_key())


def apple_audiences() -> list:
    """Client ID-ҳои иҷозатдодашудаи Apple token-ро ҷамъ мекунад."""
    extra = [a.strip() for a in settings.APPLE_MOBILE_CLIENT_IDS.split(",") if a.strip()]
    return [a for a in [settings.APPLE_CLIENT_ID, *extra] if a]


def client_secret(now: Optional[int] = None) -> str:
    """Барои Apple client secret-и кӯтоҳмуддати ES256 месозад."""
    issued = int(now or time.time())
    return jwt.encode(
        {"iss": settings.APPLE_TEAM_ID, "iat": issued, "exp": issued + 300,
         "aud": settings.APPLE_ISSUER, "sub": settings.APPLE_CLIENT_ID},
        apple_private_key(),
        algorithm="ES256",
        headers={"kid": settings.APPLE_KEY_ID},
    )


def nonce_hash(nonce: str) -> str:
    """Барои nonce hash-и SHA-256 месозад."""
    return hashlib.sha256(nonce.encode("utf-8")).hexdigest()


def _jwks_client() -> jwt.PyJWKClient:
    """Client-и муштаракро барои калидҳои имзои Apple медиҳад."""
    global _JWKS
    if _JWKS is None:
        _JWKS = jwt.PyJWKClient(settings.APPLE_KEYS_ENDPOINT, cache_keys=True, lifespan=3600)
    return _JWKS


def verify_identity_token(token: str, audiences: Iterable[str], nonce: Optional[str] = None) -> dict:
    """Имзо, issuer, audience, мӯҳлат ва nonce-и Apple token-ро месанҷад."""
    try:
        key = _jwks_client().get_signing_key_from_jwt(token).key
        claims = jwt.decode(token, key, algorithms=["RS256"], audience=list(audiences),
                            issuer=settings.APPLE_ISSUER, options={"require": ["sub", "exp", "iat"]})
    except (jwt.PyJWTError, httpx.HTTPError, OSError) as exc:
        raise HTTPException(status_code=401, detail="Воридшавӣ бо Apple тасдиқ нашуд") from exc
    if nonce is not None and claims.get("nonce") not in (nonce, nonce_hash(nonce)):
        raise HTTPException(status_code=401, detail="Воридшавӣ бо Apple тасдиқ нашуд")
    return claims


def exchange_code(code: str, redirect_uri: str) -> str:
    """Authorization code-и Apple-ро ба identity token иваз мекунад."""
    try:
        response = httpx.post(
            settings.APPLE_TOKEN_ENDPOINT,
            data={"client_id": settings.APPLE_CLIENT_ID, "client_secret": client_secret(),
                  "code": code, "grant_type": "authorization_code", "redirect_uri": redirect_uri},
            headers={"Accept": "application/json"},
            timeout=10,
        )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail="Apple ҳоло дастнорас аст. Баъдтар кӯшиш кунед") from exc
    if response.status_code != 200 or "id_token" not in response.json():
        raise HTTPException(status_code=401, detail="Воридшавӣ бо Apple тасдиқ нашуд")
    return response.json()["id_token"]


def upsert_apple_user(db: Session, claims: dict, full_name: Optional[str] = None) -> User:
    """Ҳисоби Apple-ро меёбад ё сохта, пайванди онро дар пойгоҳи додаҳо нигоҳ медорад."""
    apple_id = claims["sub"]
    email = (claims.get("email") or "").strip().lower()
    verified = str(claims.get("email_verified", "")).lower() == "true" or claims.get("email_verified") is True
    user = db.query(User).filter(User.apple_id == apple_id).first()
    if user is None and email and verified:
        user = db.query(User).filter(User.email == email).first()
        if user is not None and not user.apple_id:
            user.apple_id = apple_id
    if user is None:
        if not email:
            raise HTTPException(status_code=400, detail="Apple почтаи электрониро надод")
        user = User(email=email, full_name=(full_name or email.split("@", 1)[0]).strip(),
                    role="unassigned", apple_id=apple_id)
        db.add(user)
    elif full_name and (not user.full_name or user.full_name == user.email.split("@", 1)[0]):
        user.full_name = full_name.strip()
    db.commit()
    db.refresh(user)
    return user
