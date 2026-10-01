"""End-to-end check of the Firebase-free mobile flow.

Runs against the local SQLite database through FastAPI's TestClient and
leaves only throwaway @example.com rows, which are removed at the end.
    venv/bin/python test_mobile_v3.py
"""
import sqlite3
import uuid

from fastapi.testclient import TestClient

from app.main import app

FAILED = []


def check(label, response, expected):
    ok = response.status_code == expected
    print(f"{'ok ' if ok else 'FAIL'} {label:38} {response.status_code} {response.json().get('detail', '')}")
    if not ok:
        FAILED.append(label)
    return response.json()


def main():
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
        check("child cannot unlink", c.delete(f"/api/mobile/v2/children/{cid}", headers=H(ct, "child")), 403)
        check("parent unlinks child", c.delete(f"/api/mobile/v2/children/{cid}", headers=H(pt, "parent")), 200)
        check("logout", c.post("/api/mobile/v3/auth/logout", headers=H(ct, "child")), 200)
        check("token revoked", c.get("/api/mobile/v2/snapshot", headers=H(ct, "child")), 401)

    conn = sqlite3.connect("app/nigoh.db")
    with conn:
        ids = [r[0] for r in conn.execute("SELECT id FROM users WHERE email IN (?, ?)", emails)]
        kids = [r[0] for r in conn.execute(f"SELECT id FROM children WHERE user_id IN ({','.join('?' * len(ids))})", ids)]
        for table in ("app_rules", "app_usage_daily", "chat_messages"):
            conn.execute(f"DELETE FROM {table} WHERE child_id IN ({','.join('?' * len(kids))})", kids)
        conn.execute(f"DELETE FROM children WHERE id IN ({','.join('?' * len(kids))})", kids)
        conn.execute(f"DELETE FROM mobile_sessions WHERE user_id IN ({','.join('?' * len(ids))})", ids)
        conn.execute(f"DELETE FROM users WHERE id IN ({','.join('?' * len(ids))})", ids)
    print("\nFAILED: " + ", ".join(FAILED) if FAILED else "\nAll checks passed.")


if __name__ == "__main__":
    main()
