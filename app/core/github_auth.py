"""Файл: воридшавӣ бо GitHub, профил ва ticket-и яккаратаи app."""

import hashlib
import secrets
import time
from typing import Dict, Optional

import httpx
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.user import User

# One-time tickets for the phone flow: ticket -> {user_id, nonce_hash, created_at}.
TICKETS: Dict[str, dict] = {}


def github_configured() -> bool:
    """Мавҷуд будани credential-ҳои GitHub OAuth-ро месанҷад."""
    return bool(settings.GITHUB_CLIENT_ID and settings.GITHUB_CLIENT_SECRET)


def sha256_hex(value: str) -> str:
    """Барои қимат hash-и SHA-256-и hexadecimal месозад."""
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _api_get(path: str, token: str) -> httpx.Response:
    """Бо access token ба GitHub REST API дархости GET мефиристад."""
    return httpx.get(f"{settings.GITHUB_API}{path}", timeout=10, headers={
        "Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "NIGOH-Family"})


def fetch_identity(code: str) -> dict:
    """OAuth code-и GitHub-ро иваз карда, профил ва email-и тасдиқшударо мегирад."""
    try:
        token_resp = httpx.post(settings.GITHUB_TOKEN_ENDPOINT, timeout=10, headers={"Accept": "application/json"},
                                data={"client_id": settings.GITHUB_CLIENT_ID, "client_secret": settings.GITHUB_CLIENT_SECRET,
                                      "code": code, "redirect_uri": settings.GITHUB_REDIRECT_URI})
        token = token_resp.json().get("access_token") if token_resp.status_code == 200 else None
        if not token:
            raise HTTPException(status_code=401, detail="Воридшавӣ бо GitHub тасдиқ нашуд")
        user_resp = _api_get("/user", token)
        emails_resp = _api_get("/user/emails", token)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail="GitHub ҳоло дастнорас аст. Баъдтар кӯшиш кунед") from exc
    if user_resp.status_code != 200:
        raise HTTPException(status_code=401, detail="Воридшавӣ бо GitHub тасдиқ нашуд")
    profile = user_resp.json()
    emails = emails_resp.json() if emails_resp.status_code == 200 else []
    verified = [e for e in emails if isinstance(e, dict) and e.get("verified") and e.get("email")]
    primary = next((e["email"] for e in verified if e.get("primary")), verified[0]["email"] if verified else None)
    if not primary or not profile.get("id"):
        raise HTTPException(status_code=400, detail="GitHub почтаи тасдиқшударо надод")
    return {"id": str(profile["id"]), "login": profile.get("login") or "", "name": profile.get("name") or "",
            "avatar": profile.get("avatar_url"), "email": primary.strip().lower()}


def upsert_github_user(db: Session, identity: dict) -> User:
    """Ҳисоби GitHub-ро меёбад ё сохта, маълумоти онро сабт мекунад."""
    user = db.query(User).filter(User.github_id == identity["id"]).first()
    if user is None:
        user = db.query(User).filter(User.email == identity["email"]).first()
        if user is not None and not user.github_id:
            user.github_id = identity["id"]
    if user is None:
        user = User(email=identity["email"], full_name=(identity["name"] or identity["login"]
                                                        or identity["email"].split("@", 1)[0]),
                    role="unassigned", github_id=identity["id"], avatar=identity.get("avatar"))
        db.add(user)
    elif not user.avatar and identity.get("avatar"):
        user.avatar = identity["avatar"]
    db.commit()
    db.refresh(user)
    return user


def _prune_tickets() -> None:
    """Ticket-ҳои кӯҳнаи воридшавиро аз хотира пок мекунад."""
    cutoff = time.time() - settings.GITHUB_TICKET_MAX_AGE
    for ticket, record in list(TICKETS.items()):
        if record["created_at"] < cutoff:
            TICKETS.pop(ticket, None)


def issue_ticket(user_id: int, nonce_hash: str) -> str:
    """Барои app ticket-и кӯтоҳмуддат ва яккарата месозад."""
    _prune_tickets()
    ticket = secrets.token_urlsafe(32)
    TICKETS[ticket] = {"user_id": user_id, "nonce_hash": nonce_hash, "created_at": time.time()}
    return ticket


def redeem_ticket(ticket: str, nonce: str) -> int:
    """Ticket ва nonce-ро як бор санҷида, ID-и корбарро медиҳад."""
    _prune_tickets()
    record = TICKETS.pop(ticket, None)
    if record is None or not secrets.compare_digest(record["nonce_hash"], sha256_hex(nonce)):
        raise HTTPException(status_code=401, detail="Воридшавӣ бо GitHub тасдиқ нашуд")
    return record["user_id"]
