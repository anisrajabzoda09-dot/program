"""Файл: нигоҳдории маҳдуди маълумот ва пок кардани таърихи фарзанд (махфият)."""

from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.models.app_rule import AppRule
from app.models.app_usage import AppUsageDaily
from app.models.chat import ChatMessage
from app.models.extension_request import AppExtensionRequest
from app.models.family_extras import CallSession, CallSignal, FamilyEvent, LocationPoint, SafePlace

# Таърихи макон ҳамин қадар рӯз нигоҳ дошта мешавад; волидайн дар барнома 24 соатро мебинанд.
LOCATION_RETENTION_DAYS = 30


def _utc_naive(moment: datetime) -> datetime:
    """Вақтро ба UTC-и бе минтақа табдил медиҳад (SQLite `CURRENT_TIMESTAMP` ҳамин тавр аст)."""
    if moment.tzinfo is not None:
        moment = moment.astimezone(timezone.utc).replace(tzinfo=None)
    return moment


def prune_location_history(db: Session, child_id: int, now: datetime | None = None) -> int:
    """Нуқтаҳои макони фарзандро, ки аз LOCATION_RETENTION_DAYS кӯҳнаанд, нест мекунад."""
    cutoff = _utc_naive(now or datetime.now(timezone.utc)) - timedelta(days=LOCATION_RETENTION_DAYS)
    return db.query(LocationPoint).filter(
        LocationPoint.child_id == child_id,
        LocationPoint.created_at < cutoff,
    ).delete(synchronize_session=False)


def purge_child_history(db: Session, child_id: int) -> None:
    """Таърихи шахсии фарзандро нест мекунад: макон, чат, ҷойҳо, рӯйдодҳо, дархостҳо ва зангҳо.

    Ҳангоми хориҷ кардани фарзанд даъват мешавад, то агар телефон бо волидайни
    дигар пайваст шавад, онҳо таърихи пешинаро набинанд. Commit-ро caller мекунад.
    """
    call_ids = [row.id for row in db.query(CallSession.id).filter(CallSession.child_id == child_id)]
    if call_ids:
        db.query(CallSignal).filter(CallSignal.call_id.in_(call_ids)).delete(synchronize_session=False)
    for model in (CallSession, LocationPoint, ChatMessage, SafePlace, FamilyEvent, AppExtensionRequest):
        db.query(model).filter(model.child_id == child_id).delete(synchronize_session=False)


def delete_child_data(db: Session, child_id: int) -> None:
    """Ҳамаи маълумоти фарзандро, аз ҷумла қоидаҳо ва вақти истифода, нест мекунад."""
    purge_child_history(db, child_id)
    for model in (AppRule, AppUsageDaily):
        db.query(model).filter(model.child_id == child_id).delete(synchronize_session=False)
