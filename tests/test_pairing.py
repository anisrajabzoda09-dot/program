"""Файл: санҷиши ҳимояи рамзи пайвастшавӣ — мӯҳлати 15 дақиқа, навсозии худкор ва маҳдудияти кӯшишҳо."""

# Run from anywhere: make the project root importable and the working directory.
import os as _os, sys as _sys
_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

import uuid
from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
from app.core.security import rate_limiter
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models.child import Child

PASSED = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    """Як шартро месанҷад; хато бошад, санҷиш қатъ мешавад."""
    global PASSED
    if not ok:
        raise AssertionError(f"FAIL {name} {detail}")
    PASSED += 1
    print(f"ok  {name}")


def _utcnow() -> datetime:
    """Вақти ҳозираи UTC бе минтақа."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
Base.metadata.create_all(engine)
Session = sessionmaker(bind=engine)


def override_db():
    """Базаи санҷишӣ дар хотира."""
    db = Session()
    try:
        yield db
    finally:
        db.close()


def run_checks() -> None:
    """Сенарияҳои пайвастшавӣ бо мӯҳлат ва маҳдудият."""
    app.dependency_overrides[get_db] = override_db
    rate_limiter._history.clear()
    c = TestClient(app)
    db = Session()
    H = lambda t, r: {"Authorization": f"Bearer {t}", "X-NIGOH-Role": r}
    s = uuid.uuid4().hex[:6]
    try:
        reg = lambda e: c.post("/api/mobile/v3/auth/register", json={"email": e, "password": "longpass12", "full_name": "Т"}).json()["token"]
        pt, ct, attacker = reg(f"p{s}@x.tj"), reg(f"c{s}@x.tj"), reg(f"a{s}@x.tj")
        code = c.post("/api/mobile/v2/pair/code", json={"child_name": "Али", "gender": "boy", "age": 10}, headers=H(ct, "child")).json()
        child = db.get(Child, code["child_id"])
        expires = child.pairing_code_expires_at
        check("code expires in 15 minutes", timedelta(minutes=14) < expires - _utcnow() <= timedelta(minutes=15), str(expires))

        # 1. Рамзи кӯҳна рад мешавад ва телефони фарзанд рамзи навро бо snapshot мегирад.
        child.pairing_code_expires_at = _utcnow() - timedelta(seconds=1); db.commit()
        old = code["pairing_code"]
        r = c.post("/api/mobile/v2/pair", json={"pairing_code": old}, headers=H(pt, "parent"))
        check("expired code -> 410", r.status_code == 410, r.text)
        snap = c.get("/api/mobile/v2/snapshot", headers=H(ct, "child")).json()["child"]
        check("child snapshot rotates the code", snap["pairing_code"] != old and len(snap["pairing_code"]) == 6)
        db.expire_all()
        check("new code has a fresh expiry", db.get(Child, child.id).pairing_code_expires_at > _utcnow())
        r = c.post("/api/mobile/v2/pair", json={"pairing_code": old}, headers=H(pt, "parent"))
        check("old code no longer exists -> 404", r.status_code == 404)

        # 2. Интихоби рамз: пас аз 10 кӯшиш — 429, ҳатто бо рамзи дуруст.
        rate_limiter._history.clear()
        statuses = [c.post("/api/mobile/v2/pair", json={"pairing_code": str(100000 + i)}, headers={**H(attacker, "parent"), "X-Forwarded-For": f"10.1.0.{i}"}).status_code for i in range(10)]
        check("ten wrong guesses -> 404", statuses == [404] * 10, str(statuses))
        r = c.post("/api/mobile/v2/pair", json={"pairing_code": snap["pairing_code"]}, headers={**H(attacker, "parent"), "X-Forwarded-For": "10.1.0.99"})
        check("account limited even from a new IP", r.status_code == 429, r.text)
        rate_limiter._history.clear()
        for i in range(10):
            c.post("/api/mobile/v2/pair", json={"pairing_code": str(200000 + i)}, headers={**H(reg(f"x{i}{s}@x.tj"), "parent"), "X-Forwarded-For": "10.2.2.2"})
        r = c.post("/api/mobile/v2/pair", json={"pairing_code": snap["pairing_code"]}, headers={**H(pt, "parent"), "X-Forwarded-For": "10.2.2.2"})
        check("IP limited across many accounts", r.status_code == 429, r.text)
        r = c.post("/api/mobile/v2/pair", json={"pairing_code": snap["pairing_code"]}, headers={**H(pt, "parent"), "X-Forwarded-For": "10.3.3.3", "X-NIGOH-Lang": "en"})
        check("real parent from another IP pairs", r.status_code == 200, r.text)

        # 3. Пас аз пайваст рамз ба волидайни дигар кор намекунад; мӯҳлат дигар таъсир надорад.
        r = c.post("/api/mobile/v2/pair", json={"pairing_code": snap["pairing_code"]}, headers={**H(attacker, "parent"), "X-Forwarded-For": "10.4.4.4"})
        check("paired code refused to another family", r.status_code == 409, r.text)
        db.expire_all(); ch = db.get(Child, child.id); ch.pairing_code_expires_at = _utcnow() - timedelta(days=1); db.commit()
        c.get("/api/mobile/v2/snapshot", headers=H(ct, "child"))
        db.expire_all()
        check("paired child's code is not rotated", db.get(Child, child.id).pairing_code == snap["pairing_code"])

        # 4. Матни хато бо забони корбар.
        rate_limiter._history.clear()
        db.expire_all(); ch = db.get(Child, child.id); ch.is_paired = 0; ch.parent_id = None; db.commit()
        r = c.post("/api/mobile/v2/pair", json={"pairing_code": snap["pairing_code"]}, headers={**H(pt, "parent"), "X-NIGOH-Lang": "ru"})
        check("expired code message in Russian", r.status_code == 410 and "Срок действия кода" in r.json()["detail"], r.text)
    finally:
        rate_limiter._history.clear()
        app.dependency_overrides.clear()
        db.close()
    print(f"\nALL {PASSED} CHECKS PASSED")


if __name__ == "__main__":
    run_checks()
