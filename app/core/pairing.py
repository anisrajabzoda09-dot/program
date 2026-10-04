"""Файл: рамзи пайвасти телефони фарзанд — мӯҳлати 15 дақиқа, навсозии худкор ва ҳифз аз интихоби рамз.

Рамз 6 рақам аст (900 000 вариант), бинобар ин бе маҳдудият онро интихоб кардан мумкин мебуд.
Ҳар IP ва ҳар ҳисоби волидайн дар 15 дақиқа ҳадди аксар 10 кӯшиш дорад.
"""

import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import HTTPException, Request
from sqlalchemy.orm import Session

from app.core.security import rate_limiter
from app.models.child import Child

PAIRING_TTL = timedelta(minutes=15)
MAX_ATTEMPTS = 10
ATTEMPT_WINDOW = 15 * 60


def _now() -> datetime:
    """Вақти ҳозираи UTC бе минтақа (мисли SQLite)."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _naive(value: Optional[datetime]) -> Optional[datetime]:
    """Вақтро ба UTC-и бе минтақа меорад."""
    if value is not None and value.tzinfo is not None:
        value = value.astimezone(timezone.utc).replace(tzinfo=None)
    return value


def issue_code(db: Session, child: Child) -> str:
    """Рамзи нави 6-рақамаи беназир месозад ва мӯҳлаташро 15 дақиқа мегузорад."""
    existing = {row[0] for row in db.query(Child.pairing_code).all()}
    for _ in range(50):
        candidate = str(secrets.randbelow(900000) + 100000)
        if candidate not in existing:
            child.pairing_code = candidate
            break
    child.pairing_code_expires_at = _now() + PAIRING_TTL
    return child.pairing_code


def is_expired(child: Child) -> bool:
    """Мӯҳлати рамз гузаштааст? Сабтҳои кӯҳна бе мӯҳлат ҳамчун эътибордор ҳисоб мешаванд."""
    expires = _naive(child.pairing_code_expires_at)
    return expires is not None and expires <= _now()


def refresh_if_expired(db: Session, child: Optional[Child]) -> None:
    """Агар фарзанд пайваст нашуда ва рамзаш кӯҳна бошад, рамзи нав месозад (телефон онро бо snapshot мегирад)."""
    if child is not None and not child.is_paired and is_expired(child):
        issue_code(db, child)
        db.commit()


def check_attempt(request: Request, user_id: int) -> None:
    """Кӯшишҳои пайвастшавиро аз рӯи IP ва ҳисоб маҳдуд мекунад; зиёд бошад — 429."""
    forwarded = request.headers.get("X-Forwarded-For")
    ip = forwarded.split(",")[0].strip() if forwarded else (request.client.host if request.client else "")
    for key in (f"pair_ip:{ip}", f"pair_user:{user_id}"):
        if rate_limiter.is_rate_limited(key, MAX_ATTEMPTS, ATTEMPT_WINDOW):
            raise HTTPException(status_code=429, detail="Кӯшишҳои зиёд. Пас аз 15 дақиқа аз нав кӯшиш кунед")


def find_child(db: Session, code: str) -> Child:
    """Фарзандро аз рӯи рамз меёбад; рамзи нодуруст — 404, кӯҳна — 410."""
    child = db.query(Child).filter(Child.pairing_code == (code or "").strip().upper()).first()
    if child is None:
        raise HTTPException(status_code=404, detail="Коди фарзанд ёфт нашуд")
    if not child.is_paired and is_expired(child):
        raise HTTPException(status_code=410, detail="Мӯҳлати рамз гузашт. Рамзи навро аз телефони фарзанд гиред")
    return child
