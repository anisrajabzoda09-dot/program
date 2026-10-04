"""Файл: санҷиши нигоҳдории маҳдуди таърихи макон ва пок кардани маълумоти фарзанд."""

# Run from anywhere: make the project root importable and the working directory.
import os as _os, sys as _sys
_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

from datetime import datetime, timedelta, timezone

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import app.models  # noqa: F401  (ҳамаи model-ҳоро сабт мекунад)
from app.db.base import Base
from app.models.app_rule import AppRule
from app.models.app_usage import AppUsageDaily
from app.models.chat import ChatMessage
from app.models.child import Child
from app.models.extension_request import AppExtensionRequest
from app.models.family_extras import CallSession, CallSignal, FamilyEvent, LocationPoint, SafePlace
from app.crud.crud_privacy import (
    ANALYTICS_RETENTION_DAYS, LOCATION_RETENTION_DAYS, anonymize_site_analytics,
    delete_child_data, prune_location_history, purge_child_history,
)
from app.models.analytics import SiteAnalytics
from app.crud.crud_child import delete_child

PASSED = 0


def _utcnow() -> datetime:
    """Вақти ҳозираи UTC бе минтақа (мисли SQLite)."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def check(name: str, ok: bool, detail: str = "") -> None:
    """Як шартро месанҷад; хато бошад, санҷиш қатъ мешавад."""
    global PASSED
    if not ok:
        raise AssertionError(f"FAIL {name} {detail}")
    PASSED += 1
    print(f"ok  {name}")


def fresh_db():
    """Базаи нави SQLite дар хотира бо ҳамаи ҷадвалҳо месозад."""
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def seed(db, code: str) -> Child:
    """Як фарзанд бо ҳамаи намудҳои маълумот месозад."""
    child = Child(name="Test", pairing_code=code)
    db.add(child)
    db.flush()
    now = _utcnow()
    db.add_all([
        LocationPoint(child_id=child.id, latitude=1, longitude=2, created_at=now),
        LocationPoint(child_id=child.id, latitude=1, longitude=2, created_at=now - timedelta(days=LOCATION_RETENTION_DAYS - 1)),
        LocationPoint(child_id=child.id, latitude=1, longitude=2, created_at=now - timedelta(days=LOCATION_RETENTION_DAYS + 1)),
        LocationPoint(child_id=child.id, latitude=1, longitude=2, created_at=now - timedelta(days=400)),
        ChatMessage(child_id=child.id, sender_role="parent", sender_name="P", content="hi"),
        SafePlace(child_id=child.id, name="School", latitude=1, longitude=2),
        FamilyEvent(child_id=child.id, target_role="parent", kind="sos", title="SOS"),
        AppExtensionRequest(child_id=child.id, package_name="a.b", requested_minutes=10),
        AppRule(child_id=child.id, package_name="a.b", app_name="A"),
        AppUsageDaily(child_id=child.id, package_name="a.b", usage_date=now.date()),
    ])
    call = CallSession(child_id=child.id, caller_role="parent")
    db.add(call)
    db.flush()
    db.add(CallSignal(call_id=call.id, from_role="parent", kind="offer", payload="{}"))
    db.commit()
    return child


def count(db, model, child_id):
    """Шумораи сатрҳои model-ро барои фарзанд бармегардонад."""
    return db.query(model).filter(model.child_id == child_id).count()


def run_checks() -> None:
    """Ҳамаи сенарияҳои махфиятро иҷро мекунад."""
    db = fresh_db()
    a = seed(db, "AAA111")
    b = seed(db, "BBB222")

    # 1. Таърихи макон: танҳо нуқтаҳои аз 30 рӯз кӯҳна нест мешаванд.
    removed = prune_location_history(db, a.id)
    db.commit()
    check("prune removes only points older than retention", removed == 2, str(removed))
    check("recent points kept", count(db, LocationPoint, a.id) == 2)
    check("other child's points untouched", count(db, LocationPoint, b.id) == 4)
    check("prune is idempotent", prune_location_history(db, a.id) == 0)

    # 2. Хориҷ кардан: таърих нест мешавад, қоидаҳо мемонанд.
    purge_child_history(db, a.id)
    db.commit()
    for model in (LocationPoint, ChatMessage, SafePlace, FamilyEvent, AppExtensionRequest, CallSession):
        check(f"unlink purges {model.__tablename__}", count(db, model, a.id) == 0)
    check("unlink purges call signals", db.query(CallSignal).count() == 1)
    check("unlink keeps app rules", count(db, AppRule, a.id) == 1)
    check("unlink keeps child row", db.get(Child, a.id) is not None)
    check("unlink leaves other child intact", count(db, ChatMessage, b.id) == 1 and count(db, SafePlace, b.id) == 1)

    # 3. Нест кардани пурра (панели админ): ҳамааш, аз ҷумла қоидаҳо ва вақти истифода.
    check("delete_child returns True", delete_child(db, b.id) is True)
    for model in (LocationPoint, ChatMessage, SafePlace, FamilyEvent, AppExtensionRequest,
                  CallSession, AppRule, AppUsageDaily):
        check(f"delete removes {model.__tablename__}", count(db, model, b.id) == 0)
    check("delete removes all call signals", db.query(CallSignal).count() == 0)
    check("delete removes child row", db.get(Child, b.id) is None)
    check("delete of missing child returns False", delete_child(db, 999) is False)

    # 4. delete_child_data барои фарзанди бе маълумот хато намедиҳад.
    empty = Child(name="Empty", pairing_code="CCC333")
    db.add(empty)
    db.commit()
    delete_child_data(db, empty.id)
    db.commit()
    check("delete_child_data on empty child is safe", True)

    # 5. Омори сайт: IP ва браузер пас аз 180 рӯз пок мешаванд, сабтҳо мемонанд.
    now = _utcnow()
    db.add_all([
        SiteAnalytics(ip="1.1.1.1", path="/", user_agent="old", event_type="page_view",
                      created_at=now - timedelta(days=ANALYTICS_RETENTION_DAYS + 1)),
        SiteAnalytics(ip="2.2.2.2", path="/", user_agent="old-dl", event_type="apk_download",
                      created_at=now - timedelta(days=500)),
        SiteAnalytics(ip="3.3.3.3", path="/", user_agent="new", event_type="page_view",
                      created_at=now - timedelta(days=ANALYTICS_RETENTION_DAYS - 1)),
    ])
    db.commit()
    changed = anonymize_site_analytics(db)
    db.commit()
    check("anonymize clears only old rows", changed == 2, str(changed))
    check("old rows keep their count", db.query(SiteAnalytics).count() == 3)
    check("old IPs cleared", db.query(SiteAnalytics).filter(SiteAnalytics.ip.in_(["1.1.1.1", "2.2.2.2"])).count() == 0)
    check("old user agents cleared", db.query(SiteAnalytics).filter(SiteAnalytics.user_agent.in_(["old", "old-dl"])).count() == 0)
    check("download event kept for stats", db.query(SiteAnalytics).filter(SiteAnalytics.event_type == "apk_download").count() == 1)
    check("recent row untouched", db.query(SiteAnalytics).filter(SiteAnalytics.ip == "3.3.3.3", SiteAnalytics.user_agent == "new").count() == 1)
    check("anonymize is idempotent", anonymize_site_analytics(db) == 0)

    print(f"\nALL {PASSED} CHECKS PASSED")


if __name__ == "__main__":
    run_checks()
