"""Файл: санҷиши филтри сайтҳо аз рӯи синну сол — доменҳо, танзими волидайн, ҳолати телефон ва огоҳӣ."""

# Run from anywhere: make the project root importable and the working directory.
import os as _os, sys as _sys
_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

import uuid

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
from app.core import web_filter
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


def unit_checks() -> None:
    """Функсияҳои тоза: доменҳо, рӯйхат, сатҳҳо."""
    n = web_filter.normalize_domain
    check("plain domain", n("example.com") == "example.com")
    check("url with path and query", n("https://www.YouTube.com/watch?v=1") == "youtube.com", n("https://www.YouTube.com/watch?v=1"))
    check("port stripped", n("http://site.tj:8080/x") == "site.tj")
    check("subdomain kept", n("m.facebook.com") == "m.facebook.com")
    check("trailing dot", n("roblox.com.") == "roblox.com")
    check("cyrillic domain to punycode", n("сайт.тҷ") is not None and n("сайт.тҷ").startswith("xn--"), str(n("сайт.тҷ")))
    for bad in ("", "localhost", "192.168.1.1", "-bad.com", "a..b", "has space.com", "x" * 64 + ".com", "javascript:alert(1)"):
        check(f"rejects {bad[:20]!r}", n(bad) is None, str(n(bad)))
    items = ["YouTube.com", "youtube.com", "www.youtube.com", "bad domain", "tiktok.com"]
    check("dedupe and clean list", web_filter.normalize_blocked(items) == ["youtube.com", "tiktok.com"])
    many = [f"site{i}.com" for i in range(150)]
    check("list capped at 100", len(web_filter.normalize_blocked(many)) == web_filter.MAX_BLOCKED)
    child = Child(name="Али", pairing_code="X")
    check("default level off", web_filter.load(child) == {"level": "off", "blocked": []})
    child.web_filter_json = "{not json"
    check("broken json falls back to off", web_filter.load(child)["level"] == "off")
    child.web_filter_json = '{"level": "adult", "blocked": ["ok.com"]}'
    check("unknown level falls back to off", web_filter.load(child) == {"level": "off", "blocked": ["ok.com"]})
    saved = web_filter.save(child, "kids", ["https://Roblox.com/games"])
    check("save normalises", saved == {"level": "kids", "blocked": ["roblox.com"]})
    check("load after save", web_filter.load(child) == saved)
    try:
        web_filter.save(child, "adult", [])
        check("save rejects unknown level", False)
    except ValueError:
        check("save rejects unknown level", True)


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
    """Аз сабти ном то огоҳии волидайн тавассути API."""
    app.dependency_overrides[get_db] = override_db
    c = TestClient(app)  # бе `with`: startup ба базаи воқеӣ дахл намекунад
    H = lambda t, r: {"Authorization": f"Bearer {t}", "X-NIGOH-Role": r}
    s = uuid.uuid4().hex[:8]
    try:
        pt = c.post("/api/mobile/v3/auth/register", json={"email": f"wf_p{s}@example.com", "password": "parentpass1", "full_name": "Падар"}).json()["token"]
        ct = c.post("/api/mobile/v3/auth/register", json={"email": f"wf_c{s}@example.com", "password": "childpass1", "full_name": "Али"}).json()["token"]
        code = c.post("/api/mobile/v2/pair/code", json={"child_name": "Али", "gender": "boy", "age": 11}, headers=H(ct, "child")).json()
        cid = code["child"]["id"] if "child" in code else code["child_id"]
        check("pair", c.post("/api/mobile/v2/pair", json={"pairing_code": code["pairing_code"]}, headers=H(pt, "parent")).status_code == 200)

        snap = c.get("/api/mobile/v2/snapshot", headers=H(ct, "child")).json()["child"]
        check("snapshot has web_filter off by default", snap["web_filter"]["level"] == "off" and snap["web_filter"]["state"] is None, str(snap.get("web_filter")))

        r = c.put(f"/api/mobile/v2/children/{cid}/settings", json={"web_filter": {"level": "kids", "blocked": ["https://www.tiktok.com/", "bad site"]}}, headers=H(pt, "parent"))
        check("parent sets kids level", r.status_code == 200, r.text)
        check("response has cleaned list", r.json()["web_filter"]["blocked"] == ["tiktok.com"], r.text)
        r = c.put(f"/api/mobile/v2/children/{cid}/settings", json={"web_filter": {"level": "adult"}}, headers=H(pt, "parent"))
        check("unknown level -> 422", r.status_code == 422)
        r = c.put(f"/api/mobile/v2/children/{cid}/settings", json={"web_filter": {"level": "teen"}}, headers=H(ct, "child"))
        check("child cannot change filter", r.status_code == 403)
        r = c.put(f"/api/mobile/v2/children/{cid}/settings", json={"bedtime": {"enabled": True, "start": "21:00", "end": "07:00"}}, headers=H(pt, "parent"))
        check("other settings keep filter", r.json()["web_filter"]["level"] == "kids")

        child_view = c.get("/api/mobile/v2/snapshot", headers=H(ct, "child")).json()["child"]["web_filter"]
        check("child phone receives level and list", child_view["level"] == "kids" and child_view["blocked"] == ["tiktok.com"])

        r = c.post(f"/api/mobile/v2/children/{cid}/web-filter/state", json={"state": "active"}, headers=H(pt, "parent"))
        check("parent cannot report state", r.status_code == 403)
        r = c.post(f"/api/mobile/v2/children/{cid}/web-filter/state", json={"state": "broken"}, headers=H(ct, "child"))
        check("unknown state -> 422", r.status_code == 422)

        # Як рӯйдод, то курсори рӯйдодҳо аз 0 калон бошад (after_id=0 рӯйхати холӣ медиҳад).
        c.post(f"/api/mobile/v2/children/{cid}/chat", json={"content": "SOS", "message_type": "urgent"}, headers=H(ct, "child"))
        pos = c.get("/api/mobile/v3/events", headers=H(pt, "parent")).json()["latest_id"]
        check("event cursor ready", pos > 0, str(pos))
        r = c.post(f"/api/mobile/v2/children/{cid}/web-filter/state", json={"state": "needs_permission"}, headers=H(ct, "child"))
        check("child reports needs_permission", r.status_code == 200 and r.json()["web_filter"]["state"] == "needs_permission")
        r = c.post(f"/api/mobile/v2/children/{cid}/web-filter/state", json={"state": "active"}, headers=H(ct, "child"))
        check("child reports active", r.json()["web_filter"]["state"] == "active" and r.json()["web_filter"]["reported_at"])
        kinds = [e["kind"] for e in c.get(f"/api/mobile/v3/events?after_id={pos}", headers=H(pt, "parent")).json()["events"]]
        check("no alert before the filter was ever active", "web_filter_off" not in kinds, str(kinds))

        r = c.post(f"/api/mobile/v2/children/{cid}/web-filter/state", json={"state": "off"}, headers=H(ct, "child"))
        events = c.get(f"/api/mobile/v3/events?after_id={pos}", headers=H(pt, "parent")).json()["events"]
        alerts = [e for e in events if e["kind"] == "web_filter_off"]
        check("parent alerted when filter turned off", len(alerts) == 1, str(events))
        check("alert names the child", "Али" in alerts[0]["title"])
        c.post(f"/api/mobile/v2/children/{cid}/web-filter/state", json={"state": "off"}, headers=H(ct, "child"))
        events = c.get(f"/api/mobile/v3/events?after_id={pos}", headers=H(pt, "parent")).json()["events"]
        check("alert not repeated while still off", sum(e["kind"] == "web_filter_off" for e in events) == 1)

        parent_kid = next(k for k in c.get("/api/mobile/v2/snapshot", headers=H(pt, "parent")).json()["children"] if k["id"] == cid)
        check("parent sees state off", parent_kid["web_filter"]["state"] == "off")

        c.put(f"/api/mobile/v2/children/{cid}/settings", json={"web_filter": {"level": "off", "blocked": []}}, headers=H(pt, "parent"))
        c.post(f"/api/mobile/v2/children/{cid}/web-filter/state", json={"state": "active"}, headers=H(ct, "child"))
        pos2 = c.get("/api/mobile/v3/events", headers=H(pt, "parent")).json()["latest_id"]
        c.post(f"/api/mobile/v2/children/{cid}/web-filter/state", json={"state": "off"}, headers=H(ct, "child"))
        kinds = [e["kind"] for e in c.get(f"/api/mobile/v3/events?after_id={pos2}", headers=H(pt, "parent")).json()["events"]]
        check("no alert when parent turned the filter off", "web_filter_off" not in kinds, str(kinds))
    finally:
        app.dependency_overrides.clear()


if __name__ == "__main__":
    unit_checks()
    api_checks()
    print(f"\nALL {PASSED} CHECKS PASSED")
