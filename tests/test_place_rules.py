"""Файл: санҷиши қоидаҳои барномаҳо аз рӯи ҷой ва огоҳии «расид / баромад»."""

# Run from anywhere: make the project root importable and the working directory.
import os as _os, sys as _sys
_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

import uuid
from types import SimpleNamespace

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
from app.core import place_rules as pr
from app.core.security import rate_limiter
from app.db.base import Base
from app.db.session import get_db
from app.main import app

PASSED = 0
SCHOOL = (38.5598, 68.7870)


def check(name: str, ok: bool, detail: str = "") -> None:
    """Як шартро месанҷад; хато бошад, санҷиш қатъ мешавад."""
    global PASSED
    if not ok:
        raise AssertionError(f"FAIL {name} {detail}")
    PASSED += 1
    print(f"ok  {name}")


def north(meters: float):
    """Нуқтае, ки ин қадар метр ба шимоли мактаб аст."""
    return SCHOOL[0] + meters / 111_195.0, SCHOOL[1]


def unit_checks() -> None:
    """Функсияҳои тоза: тозакунии қоидаҳо, масофа ва фосилаи эҳтиётӣ."""
    n = pr.normalize_rules({"apps": {
        "com.tiktok": {"mode": "block"},
        "org.telegram": {"mode": "limit", "minutes": 2},
        "com.youtube": {"mode": "limit", "minutes": 5000},
        "com.duolingo": {"mode": "allow", "minutes": 30},
        "bad": {"mode": "explode"},
        "nolimit": {"mode": "limit"},
        "": {"mode": "block"},
    }, "notify": 1})
    check("block kept", n["apps"]["com.tiktok"] == {"mode": "block"})
    check("limit raised to 5", n["apps"]["org.telegram"] == {"mode": "limit", "minutes": 5})
    check("limit capped at 720", n["apps"]["com.youtube"]["minutes"] == 720)
    check("allow drops minutes", n["apps"]["com.duolingo"] == {"mode": "allow"})
    check("unknown mode, empty name and missing minutes dropped", set(n["apps"]) == {"com.tiktok", "org.telegram", "com.youtube", "com.duolingo"})
    check("notify as bool", n["notify"] is True)
    check("garbage -> empty", pr.normalize_rules("x") == {"apps": {}, "notify": False})
    check("distance ~100 m", abs(pr.distance_meters(*SCHOOL, *north(100)) - 100) < 1)

    school = SimpleNamespace(id=1, latitude=SCHOOL[0], longitude=SCHOOL[1], radius_meters=150, name="Мактаб", rules_json='{"notify": true}')
    home = SimpleNamespace(id=2, latitude=north(1000)[0], longitude=SCHOOL[1], radius_meters=100, name="Хона", rules_json=None)
    places = [school, home]
    check("inside school", pr.place_at(*north(100), places) is school)
    check("outside everything", pr.place_at(*north(500), places) is None)
    check("just outside radius, not yet inside -> none", pr.place_at(*north(170), places) is None)
    check("just outside radius while inside -> still school (hysteresis)", pr.place_at(*north(170), places, current_id=1) is school)
    check("well outside while inside -> left", pr.place_at(*north(200), places, current_id=1) is None)
    check("home", pr.place_at(*north(1000), places) is home)


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


def api_checks() -> None:
    """Аз сохтани ҷой то огоҳиҳо тавассути API."""
    app.dependency_overrides[get_db] = override_db
    rate_limiter._history.clear()
    c = TestClient(app)
    H = lambda t, r: {"Authorization": f"Bearer {t}", "X-NIGOH-Role": r}
    s = uuid.uuid4().hex[:6]
    try:
        reg = lambda e: c.post("/api/mobile/v3/auth/register", json={"email": e, "password": "longpass12", "full_name": "Т"}).json()["token"]
        pt, ct = reg(f"pp{s}@x.tj"), reg(f"pc{s}@x.tj")
        code = c.post("/api/mobile/v2/pair/code", json={"child_name": "Али", "gender": "boy", "age": 10}, headers=H(ct, "child")).json()
        cid = code["child_id"]
        c.post("/api/mobile/v2/pair", json={"pairing_code": code["pairing_code"]}, headers=H(pt, "parent"))
        place = c.post(f"/api/mobile/v2/children/{cid}/places", json={"name": "Мактаб", "latitude": SCHOOL[0], "longitude": SCHOOL[1], "radius_meters": 150}, headers=H(pt, "parent")).json()["place"]
        check("new place has empty rules", place["rules"] == {} and place["notify"] is False, str(place))

        rules = {"apps": {"com.zhiliaoapp.musically": {"mode": "block"}, "org.telegram.messenger": {"mode": "limit", "minutes": 20}, "com.duolingo": {"mode": "allow"}}, "notify": True}
        r = c.put(f"/api/mobile/v2/children/{cid}/places/{place['id']}", json={"rules": rules}, headers=H(pt, "parent"))
        check("parent saves place rules", r.status_code == 200 and r.json()["place"]["rules"]["org.telegram.messenger"] == {"mode": "limit", "minutes": 20}, r.text)
        check("notify saved", r.json()["place"]["notify"] is True)
        r = c.put(f"/api/mobile/v2/children/{cid}/places/{place['id']}", json={"rules": {"apps": {"a": {"mode": "nuke"}}}}, headers=H(pt, "parent"))
        check("bad mode -> 422", r.status_code == 422)
        r = c.put(f"/api/mobile/v2/children/{cid}/places/{place['id']}", json={"rules": {"apps": {"a": {"mode": "limit", "minutes": 1}}}}, headers=H(pt, "parent"))
        check("limit under 5 -> 422", r.status_code == 422)
        r = c.put(f"/api/mobile/v2/children/{cid}/places/{place['id']}", json={"name": "Хона"}, headers=H(ct, "child"))
        check("child cannot change places", r.status_code == 403)
        r = c.put(f"/api/mobile/v2/children/{cid}/places/99999", json={"name": "X"}, headers=H(pt, "parent"))
        check("unknown place -> 404", r.status_code == 404)
        r = c.put(f"/api/mobile/v2/children/{cid}/places/{place['id']}", json={"name": " Мактаби №24 ", "radius_meters": 200}, headers=H(pt, "parent"))
        check("rename keeps rules", r.json()["place"]["name"] == "Мактаби №24" and r.json()["place"]["radius_meters"] == 200 and len(r.json()["place"]["rules"]) == 3)

        snap = c.get("/api/mobile/v2/snapshot", headers=H(ct, "child")).json()["child"]
        check("child snapshot carries places with rules", snap["places"][0]["rules"]["com.duolingo"] == {"mode": "allow"})
        check("current place unknown at first", snap["current_place_id"] is None)

        # Огоҳиҳо: SOS барои курсори рӯйдодҳо, баъд омадан ва рафтан.
        c.post(f"/api/mobile/v2/children/{cid}/chat", json={"content": "SOS", "message_type": "urgent"}, headers=H(ct, "child"))
        pos = c.get("/api/mobile/v3/events", headers=H(pt, "parent")).json()["latest_id"]
        loc = lambda lat, lng, acc=10: c.post(f"/api/mobile/v2/children/{cid}/location", json={"latitude": lat, "longitude": lng, "accuracy": acc, "battery_level": 80, "is_online": True}, headers=H(ct, "child"))
        loc(*north(1500)); loc(*north(100))
        ev = c.get(f"/api/mobile/v3/events?after_id={pos}", headers=H(pt, "parent")).json()["events"]
        check("arrive alert", [e["kind"] for e in ev] == ["place_arrive"] and "Мактаби №24" in ev[0]["title"], str(ev))
        check("child snapshot knows the place", c.get("/api/mobile/v2/snapshot", headers=H(ct, "child")).json()["child"]["current_place_id"] == place["id"])
        loc(*north(150)); loc(*north(230))
        ev = c.get(f"/api/mobile/v3/events?after_id={pos}", headers=H(pt, "parent")).json()["events"]
        check("no flapping at the edge (230 m < 200 + 40)", [e["kind"] for e in ev] == ["place_arrive"], str([e["kind"] for e in ev]))
        loc(*north(400), acc=900)
        ev = c.get(f"/api/mobile/v3/events?after_id={pos}", headers=H(pt, "parent")).json()["events"]
        check("inaccurate fix ignored", len(ev) == 1)
        loc(*north(400))
        ev = c.get(f"/api/mobile/v3/events?after_id={pos}", headers=H(pt, "parent")).json()["events"]
        check("leave alert", [e["kind"] for e in ev] == ["place_arrive", "place_leave"], str([e["kind"] for e in ev]))
        check("leave data names the place", ev[1]["data"]["place"] == "Мактаби №24")

        # Бе «notify» огоҳӣ нест, вале ҷойи ҳозира нав мешавад.
        c.put(f"/api/mobile/v2/children/{cid}/places/{place['id']}", json={"rules": {"apps": {}, "notify": False}}, headers=H(pt, "parent"))
        loc(*north(50))
        ev = c.get(f"/api/mobile/v3/events?after_id={pos}", headers=H(pt, "parent")).json()["events"]
        check("no alert when notify is off", len(ev) == 2)
        check("current place still tracked", c.get("/api/mobile/v2/snapshot", headers=H(ct, "child")).json()["child"]["current_place_id"] == place["id"])
        c.delete(f"/api/mobile/v2/children/{cid}/places/{place['id']}", headers=H(pt, "parent"))
        r = loc(*north(50))
        check("deleted place clears current place", r.status_code == 200 and c.get("/api/mobile/v2/snapshot", headers=H(ct, "child")).json()["child"]["current_place_id"] is None)
    finally:
        rate_limiter._history.clear()
        app.dependency_overrides.clear()


if __name__ == "__main__":
    unit_checks()
    api_checks()
    print(f"\nALL {PASSED} CHECKS PASSED")
