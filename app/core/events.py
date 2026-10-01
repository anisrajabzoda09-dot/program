"""Creating notification events for the phones (see FamilyEvent)."""

import json
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy.orm import Session

from app.models.child import Child
from app.models.family_extras import FamilyEvent

LOW_BATTERY = 15
BATTERY_RESET = 20
OFFLINE_AFTER = timedelta(minutes=20)


def emit(
    db: Session,
    child: Child,
    target_role: str,
    kind: str,
    title: str,
    body: str = "",
    data: Optional[dict] = None,
) -> FamilyEvent:
    """Queue an event; the caller commits."""
    event = FamilyEvent(
        child_id=child.id,
        target_role=target_role,
        kind=kind,
        title=title[:160],
        body=(body or "")[:500],
        data_json=json.dumps(data or {}, ensure_ascii=False),
    )
    db.add(event)
    return event


def on_battery(db: Session, child: Child, level: Optional[int]) -> None:
    """Notify the parent once when the battery drops below 15 %."""
    if level is None:
        return
    if level < LOW_BATTERY and not child.low_battery_notified:
        child.low_battery_notified = 1
        emit(db, child, "parent", "low_battery", f"{child.name}: батарея {level}%",
             "Телефони фарзанд ба зудӣ хомӯш мешавад.", {"battery": level})
    elif level >= BATTERY_RESET and child.low_battery_notified:
        child.low_battery_notified = 0


def on_seen(child: Child) -> None:
    """The phone reported in: allow a new «offline» alert later."""
    child.offline_notified = 0


def check_offline(db: Session, children: list) -> None:
    """Notify the parent once when a child's phone has been silent for 20 min."""
    now = datetime.now(timezone.utc)
    for child in children:
        seen = child.location_updated_at
        if seen is None or child.offline_notified or not child.is_paired:
            continue
        if seen.tzinfo is None:
            seen = seen.replace(tzinfo=timezone.utc)
        if now - seen > OFFLINE_AFTER:
            child.offline_notified = 1
            emit(db, child, "parent", "offline", f"{child.name} офлайн аст",
                 "Телефони фарзанд 20 дақиқа боз ба интернет пайваст нашудааст.")
