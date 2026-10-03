"""End-to-end check of the Firebase-free mobile flow.

Runs against the local SQLite database through FastAPI's TestClient and
leaves only throwaway @example.com rows, which are removed at the end.
    venv/bin/python tests/test_mobile_v3.py
"""

# Run from anywhere: make the project root importable and the working directory.
import os as _os, sys as _sys
_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

import sqlite3
import uuid

from fastapi.testclient import TestClient

from app.main import app

FAILED = []


def check(label, response, expected):
    """Record whether an API response matches the expected status and decode it."""

    ok = response.status_code == expected
    print(f"{'ok ' if ok else 'FAIL'} {label:38} {response.status_code} {response.json().get('detail', '')}")
    if not ok:
        FAILED.append(label)
    return response.json()


def main():
    """Exercise the complete mobile family workflow and remove test records."""

    s = uuid.uuid4().hex[:8]
    emails = [f"qa_p{s}@example.com", f"qa_c{s}@example.com"]
    with TestClient(app) as c:
        H = lambda t, r: {"Authorization": f"Bearer {t}", "X-NIGOH-Role": r}
        pt = check("register parent", c.post("/api/mobile/v3/auth/register", json={"email": emails[0], "password": "parentpass1", "full_name": "Падар"}), 200)["token"]
        check("register child", c.post("/api/mobile/v3/auth/register", json={"email": emails[1], "password": "childpass1", "full_name": "Али"}), 200)
        check("duplicate register", c.post("/api/mobile/v3/auth/register", json={"email": emails[1], "password": "childpass1", "full_name": "Али"}), 400)
        check("short password", c.post("/api/mobile/v3/auth/register", json={"email": f"x{s}@example.com", "password": "123", "full_name": "X"}), 422)
        check("wrong password", c.post("/api/mobile/v3/auth/login", json={"email": emails[1], "password": "nope"}), 400)
        ct = check("login child", c.post("/api/mobile/v3/auth/login", json={"email": emails[1], "password": "childpass1"}), 200)["token"]
        check("no token", c.get("/api/mobile/v2/snapshot"), 401)
        check("forged token", c.get("/api/mobile/v2/snapshot", headers=H("ngh_forged", "child")), 401)
        snap = check("child snapshot before pairing", c.get("/api/mobile/v2/snapshot", headers=H(ct, "child")), 200)
        assert snap["child"] is None
        # The bug seen in production: an account first used as parent could
        # never create a child code (403). The phone's chosen role now wins.
        check("parent account used as child", c.post("/api/mobile/v2/pair/code", json={"child_name": "T", "gender": "boy", "age": 10}, headers=H(pt, "child")), 200)
        code = check("child creates pairing code", c.post("/api/mobile/v2/pair/code", json={"child_name": "Али", "gender": "boy", "age": 11}, headers=H(ct, "child")), 200)
        cid = code["child_id"]
        check("parent pairs", c.post("/api/mobile/v2/pair", json={"pairing_code": code["pairing_code"]}, headers=H(pt, "parent")), 200)
        check("apps sync", c.post(f"/api/mobile/v2/children/{cid}/apps/sync", json={"apps": [{"package_name": "com.whatsapp", "app_name": "WhatsApp", "usage_minutes": 12}]}, headers=H(ct, "child")), 200)
        kids = check("parent snapshot", c.get("/api/mobile/v2/snapshot", headers=H(pt, "parent")), 200)["children"]
        kid = next(k for k in kids if k["id"] == cid)
        assert [a["package_name"] for a in kid["apps"]] == ["com.whatsapp"], kid["apps"]
        check("parent blocks app", c.put(f"/api/mobile/v2/children/{cid}/apps/com.whatsapp", json={"is_blocked": True}, headers=H(pt, "parent")), 200)
        child_apps = c.get("/api/mobile/v2/snapshot", headers=H(ct, "child")).json()["child"]["apps"]
        assert child_apps[0]["is_blocked"] in (1, True)
        check("chat from parent", c.post(f"/api/mobile/v2/children/{cid}/chat", json={"content": "Салом"}, headers=H(pt, "parent")), 200)
        check("chat from child", c.post(f"/api/mobile/v2/children/{cid}/chat", json={"content": "Салом падар"}, headers=H(ct, "child")), 200)
        msgs = check("chat history", c.get(f"/api/mobile/v2/children/{cid}/chat", headers=H(pt, "parent")), 200)["messages"]
        assert [(m["sender_role"], m["content"]) for m in msgs] == [("parent", "Салом"), ("child", "Салом падар")]
        check("location", c.post(f"/api/mobile/v2/children/{cid}/location", json={"latitude": 38.56, "longitude": 68.78, "accuracy": 10, "battery_level": 80, "is_online": True}, headers=H(ct, "child")), 200)
        check("profile", c.get("/api/mobile/v3/me", headers=H(ct, "child")), 200)
        # --- family features ---
        pts = check("location history", c.get(f"/api/mobile/v2/children/{cid}/locations", headers=H(pt, "parent")), 200)["points"]
        assert len(pts) == 1 and pts[0]["latitude"] == 38.56
        days = check("usage history", c.get(f"/api/mobile/v2/children/{cid}/usage?days=7", headers=H(pt, "parent")), 200)["days"]
        assert len(days) == 7 and days[-1]["minutes"] == 12 and days[-1]["top"][0]["app_name"] == "WhatsApp"
        check("parent cannot request time", c.post(f"/api/mobile/v2/children/{cid}/requests", json={"package_name": "com.whatsapp", "minutes": 15}, headers=H(pt, "parent")), 403)
        req = check("child requests time", c.post(f"/api/mobile/v2/children/{cid}/requests", json={"package_name": "com.whatsapp", "minutes": 15, "reason": "дарс"}, headers=H(ct, "child")), 200)["request"]
        check("duplicate request", c.post(f"/api/mobile/v2/children/{cid}/requests", json={"package_name": "com.whatsapp", "minutes": 15}, headers=H(ct, "child")), 409)
        pend = check("parent sees pending", c.get(f"/api/mobile/v2/children/{cid}/requests?status=pending", headers=H(pt, "parent")), 200)["requests"]
        assert pend[0]["app_name"] == "WhatsApp"
        check("child cannot decide", c.post(f"/api/mobile/v2/children/{cid}/requests/{req['id']}/decision", json={"approve": True}, headers=H(ct, "child")), 403)
        check("parent approves", c.post(f"/api/mobile/v2/children/{cid}/requests/{req['id']}/decision", json={"approve": True}, headers=H(pt, "parent")), 200)
        check("parent gives bonus", c.post(f"/api/mobile/v2/children/{cid}/apps/com.whatsapp/bonus", json={"minutes": 30}, headers=H(pt, "parent")), 200)
        app_row = c.get("/api/mobile/v2/snapshot", headers=H(ct, "child")).json()["child"]["apps"][0]
        assert app_row["bonus_minutes_today"] == 45, app_row
        assert app_row["first_seen_at"]
        check("always allowed", c.put(f"/api/mobile/v2/children/{cid}/apps/com.whatsapp", json={"always_allowed": True}, headers=H(pt, "parent")), 200)
        check("bedtime", c.put(f"/api/mobile/v2/children/{cid}/settings", json={"bedtime": {"enabled": True, "start": "21:30", "end": "07:00"}}, headers=H(pt, "parent")), 200)
        check("bad bedtime", c.put(f"/api/mobile/v2/children/{cid}/settings", json={"bedtime": {"enabled": True, "start": "25:00", "end": "07:00"}}, headers=H(pt, "parent")), 422)
        place = check("add safe place", c.post(f"/api/mobile/v2/children/{cid}/places", json={"name": "Хона", "latitude": 38.56, "longitude": 68.78, "radius_meters": 200}, headers=H(pt, "parent")), 200)["place"]
        assert check("child sees places", c.get(f"/api/mobile/v2/children/{cid}/places", headers=H(ct, "child")), 200)["places"][0]["name"] == "Хона"
        check("sos", c.post(f"/api/mobile/v2/children/{cid}/chat", json={"content": "SOS", "message_type": "urgent"}, headers=H(ct, "child")), 200)
        kid = next(k for k in c.get("/api/mobile/v2/snapshot", headers=H(pt, "parent")).json()["children"] if k["id"] == cid)
        assert kid["bedtime"]["enabled"] and kid["apps"][0]["always_allowed"] is True
        assert kid["last_urgent"]["content"] == "SOS" and kid["unread_from_child"] == 2 and kid["pending_requests"] == 0, kid
        check("parent reads chat", c.post(f"/api/mobile/v2/children/{cid}/chat/read", headers=H(pt, "parent")), 200)
        kid = next(k for k in c.get("/api/mobile/v2/snapshot", headers=H(pt, "parent")).json()["children"] if k["id"] == cid)
        assert kid["unread_from_child"] == 0 and kid["last_urgent"] is None
        # --- notifications (events) ---
        pos = check("parent event cursor", c.get("/api/mobile/v3/events", headers=H(pt, "parent")), 200)["latest_id"]
        cpos = check("child event cursor", c.get("/api/mobile/v3/events", headers=H(ct, "child")), 200)["latest_id"]
        check("message to child", c.post(f"/api/mobile/v2/children/{cid}/chat", json={"content": "Салом писарам"}, headers=H(pt, "parent")), 200)
        ev = check("child gets message event", c.get(f"/api/mobile/v3/events?after_id={cpos}&wait=3", headers=H(ct, "child")), 200)
        assert [e["kind"] for e in ev["events"]] == ["message"] and ev["events"][0]["body"] == "Салом писарам", ev
        check("sos 2", c.post(f"/api/mobile/v2/children/{cid}/chat", json={"content": "SOS!", "message_type": "urgent"}, headers=H(ct, "child")), 200)
        check("low battery", c.post(f"/api/mobile/v2/children/{cid}/location", json={"latitude": 38.5, "longitude": 68.7, "battery_level": 9}, headers=H(ct, "child")), 200)
        check("low battery again", c.post(f"/api/mobile/v2/children/{cid}/location", json={"latitude": 38.5, "longitude": 68.7, "battery_level": 8}, headers=H(ct, "child")), 200)
        check("new app installed", c.post(f"/api/mobile/v2/children/{cid}/apps/sync", json={"apps": [{"package_name": "com.whatsapp", "app_name": "WhatsApp"}, {"package_name": "com.roblox.client", "app_name": "Roblox"}]}, headers=H(ct, "child")), 200)
        kinds = [e["kind"] for e in c.get(f"/api/mobile/v3/events?after_id={pos}", headers=H(pt, "parent")).json()["events"]]
        assert kinds == ["sos", "low_battery", "new_app"], kinds
        check("study mode", c.put(f"/api/mobile/v2/children/{cid}/settings", json={"study": {"enabled": True, "start": "08:00", "end": "13:00", "weekdays": [1, 2, 3, 4, 5, 9]}}, headers=H(pt, "parent")), 200)
        kid = next(k for k in c.get("/api/mobile/v2/snapshot", headers=H(pt, "parent")).json()["children"] if k["id"] == cid)
        assert kid["study"]["weekdays"] == [1, 2, 3, 4, 5] and kid["bedtime"]["enabled"] and kid["battery_level"] == 8, kid
        # --- calls ---
        check("ice config", c.get("/api/mobile/v3/calls/config", headers=H(pt, "parent")), 200)
        cpos = c.get("/api/mobile/v3/events", headers=H(ct, "child")).json()["latest_id"]
        call = check("parent calls child", c.post("/api/mobile/v3/calls", json={"child_id": cid}, headers=H(pt, "parent")), 200)["call"]
        ev = c.get(f"/api/mobile/v3/events?after_id={cpos}", headers=H(ct, "child")).json()["events"]
        assert ev[-1]["kind"] == "call" and ev[-1]["data"]["call_id"] == call["id"], ev
        check("caller cannot accept own call", c.post(f"/api/mobile/v3/calls/{call['id']}/accept", headers=H(pt, "parent")), 409)
        check("child accepts", c.post(f"/api/mobile/v3/calls/{call['id']}/accept", headers=H(ct, "child")), 200)
        check("offer", c.post(f"/api/mobile/v3/calls/{call['id']}/signal", json={"kind": "offer", "payload": "{\"sdp\":\"x\"}"}, headers=H(pt, "parent")), 200)
        sig = check("child gets offer", c.get(f"/api/mobile/v3/calls/{call['id']}/signals?wait=2", headers=H(ct, "child")), 200)
        assert [x["kind"] for x in sig["signals"]] == ["offer"] and sig["call"]["status"] == "active"
        check("answer", c.post(f"/api/mobile/v3/calls/{call['id']}/signal", json={"kind": "answer", "payload": "{}"}, headers=H(ct, "child")), 200)
        assert [x["kind"] for x in c.get(f"/api/mobile/v3/calls/{call['id']}/signals", headers=H(pt, "parent")).json()["signals"]] == ["answer"]
        check("parent hangs up", c.post(f"/api/mobile/v3/calls/{call['id']}/end", headers=H(pt, "parent")), 200)
        check("no signals after end", c.post(f"/api/mobile/v3/calls/{call['id']}/signal", json={"kind": "ice", "payload": "{}"}, headers=H(ct, "child")), 409)
        call2 = c.post("/api/mobile/v3/calls", json={"child_id": cid}, headers=H(ct, "child")).json()["call"]
        sqlite3.connect("app/nigoh.db").execute("UPDATE call_sessions SET created_at = datetime('now', '-2 minutes') WHERE id = ?", (call2["id"],)).connection.commit()
        assert c.get(f"/api/mobile/v3/calls/{call2['id']}", headers=H(pt, "parent")).json()["call"]["status"] == "missed"
        check("delete safe place", c.delete(f"/api/mobile/v2/children/{cid}/places/{place['id']}", headers=H(pt, "parent")), 200)
        other = check("stranger cannot read history", c.get(f"/api/mobile/v2/children/{cid}/locations", headers=H(pt, "child")), 404)
        check("child cannot unlink", c.delete(f"/api/mobile/v2/children/{cid}", headers=H(ct, "child")), 403)
        check("parent unlinks child", c.delete(f"/api/mobile/v2/children/{cid}", headers=H(pt, "parent")), 200)
        check("logout", c.post("/api/mobile/v3/auth/logout", headers=H(ct, "child")), 200)
        check("token revoked", c.get("/api/mobile/v2/snapshot", headers=H(ct, "child")), 401)

    conn = sqlite3.connect("app/nigoh.db")
    with conn:
        ids = [r[0] for r in conn.execute("SELECT id FROM users WHERE email IN (?, ?)", emails)]
        kids = [r[0] for r in conn.execute(f"SELECT id FROM children WHERE user_id IN ({','.join('?' * len(ids))})", ids)]
        calls = [r[0] for r in conn.execute(f"SELECT id FROM call_sessions WHERE child_id IN ({','.join('?' * len(kids))})", kids)]
        conn.execute(f"DELETE FROM call_signals WHERE call_id IN ({','.join('?' * len(calls))})", calls)
        for table in ("app_rules", "app_usage_daily", "chat_messages", "location_points", "safe_places", "app_extension_requests", "family_events", "call_sessions"):
            conn.execute(f"DELETE FROM {table} WHERE child_id IN ({','.join('?' * len(kids))})", kids)
        conn.execute(f"DELETE FROM children WHERE id IN ({','.join('?' * len(kids))})", kids)
        conn.execute(f"DELETE FROM mobile_sessions WHERE user_id IN ({','.join('?' * len(ids))})", ids)
        conn.execute(f"DELETE FROM users WHERE id IN ({','.join('?' * len(ids))})", ids)
    print("\nFAILED: " + ", ".join(FAILED) if FAILED else "\nAll checks passed.")


if __name__ == "__main__":
    main()
