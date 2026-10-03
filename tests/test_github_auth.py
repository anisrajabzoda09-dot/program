"""End-to-end checks for Sign in with GitHub (website flow, phone ticket flow, account linking).

GitHub is simulated by patching the HTTP calls to its token endpoint and REST
API. Test accounts are deleted at the end.
"""
# Run from anywhere: make the project root importable and the working directory.
import os as _os, sys as _sys
_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

import secrets
import time
import uuid
from urllib.parse import parse_qs, urlparse

from fastapi.testclient import TestClient
from sqlalchemy import text

from app.core import github_auth
from app.core.config import settings
from app.db.session import SessionLocal
from app.main import app
from app.models.user import User

FAILS = []


def check(label, ok, detail=""):
    """Print one check result and remember failures."""
    print(f"{'ok ' if ok else 'FAIL'} {label}{(' — ' + str(detail)) if detail and not ok else ''}")
    if not ok:
        FAILS.append(label)


class _Resp:
    """Minimal httpx.Response stand-in."""
    def __init__(self, payload, status=200):
        self._p, self.status_code = payload, status

    def json(self):
        """Return the canned JSON body."""
        return self._p


GH = {}
SEEN = {}


def fake_post(url, data=None, **kw):
    """Pretend to be GitHub's token endpoint; checks we send our secret and the code."""
    SEEN["token_request"] = dict(data or {})
    if not GH.get("token_ok", True):
        return _Resp({"error": "bad_verification_code"})
    return _Resp({"access_token": "gho_test_token", "token_type": "bearer"})


def fake_get(url, headers=None, **kw):
    """Pretend to be GitHub's REST API for /user and /user/emails."""
    assert headers["Authorization"] == "Bearer gho_test_token"
    if url.endswith("/user/emails"):
        return _Resp(GH["emails"])
    return _Resp(GH["user"])


def set_github(uid, login, email, verified=True, extra_emails=(), name="Test Dev"):
    """Configure the simulated GitHub account for the next sign-in."""
    GH["user"] = {"id": uid, "login": login, "name": name, "avatar_url": f"https://avatars.example/{uid}"}
    GH["emails"] = [{"email": email, "primary": True, "verified": verified}, *extra_emails]
    GH["token_ok"] = True


def start_web(c, lang=""):
    """Begin the website flow; return (state, response)."""
    r = c.get(f"/auth/github/login?next=%2Fget{lang}", follow_redirects=False)
    return parse_qs(urlparse(r.headers["location"]).query).get("state", [""])[0], r


def main():
    """Run every GitHub sign-in scenario and clean up the accounts it created."""
    tag = uuid.uuid4().hex[:8]
    base_id = int(time.time() * 1000) % 10**9
    emails = [f"qa_gh_{tag}@example.com", f"qa_gh_new_{tag}@example.com", f"qa_gh_link_{tag}@example.com",
              f"qa_gh_victim_{tag}@example.com", f"qa_gh_att_{tag}@example.com", f"qa_gh_m_{tag}@example.com"]
    saved = {k: getattr(settings, k) for k in ("GITHUB_CLIENT_ID", "GITHUB_CLIENT_SECRET")}
    real_post, real_get = github_auth.httpx.post, github_auth.httpx.get
    try:
        with TestClient(app, base_url="https://testserver") as c:
            settings.GITHUB_CLIENT_ID = settings.GITHUB_CLIENT_SECRET = ""
            check("not configured: web login shows the notice",
                  c.get("/auth/github/login", follow_redirects=False).headers["location"] == "/auth?github=not_configured")
            check("not configured: app flow returns an error to the app",
                  c.get("/auth/github/mobile?nonce_hash=" + "a" * 64, follow_redirects=False).headers["location"]
                  == "nigohfamily://auth/github?error=not_configured")
            check("not configured: no GitHub button", 'id="githubSignInBtn"' not in c.get("/auth").text)
            check("not configured: app config disabled",
                  c.get("/api/mobile/v3/auth/github/config").json()["enabled"] is False)

            settings.GITHUB_CLIENT_ID, settings.GITHUB_CLIENT_SECRET = "Iv1.testclient", "test-secret"
            github_auth.httpx.post, github_auth.httpx.get = fake_post, fake_get
            for path, label in (("/auth", "Идома бо GitHub"), ("/auth?lang=ru", "Продолжить с GitHub"),
                                ("/auth?lang=en", "Continue with GitHub")):
                html = c.get(path).text
                check(f"button shown: {label}", 'id="githubSignInBtn"' in html and label in html)
            cfg = c.get("/api/mobile/v3/auth/github/config").json()
            check("app config: start URL and scheme, no secret",
                  cfg == {"enabled": True, "start_url": "https://nigohfamily.qobus.tj/auth/github/mobile",
                          "callback_scheme": "nigohfamily"}, cfg)

            state, r = start_web(c)
            loc = urlparse(r.headers["location"]); q = parse_qs(loc.query)
            cookie = r.headers.get("set-cookie", "").lower()
            check("login goes to GitHub with client id, scope, redirect and state",
                  loc.netloc == "github.com" and q["client_id"] == ["Iv1.testclient"]
                  and q["scope"] == ["read:user user:email"]
                  and q["redirect_uri"] == ["https://nigohfamily.qobus.tj/auth/github/callback"] and len(state) > 20)
            check("state cookie is HttpOnly + SameSite=Lax + Secure",
                  "github_oauth_state=" in cookie and "samesite=lax" in cookie and "httponly" in cookie and "secure" in cookie, cookie)

            # --- happy path
            gid = base_id + 1
            set_github(gid, f"dev{tag}", emails[0])
            r = c.get(f"/auth/github/callback?code=c1&state={state}", follow_redirects=False)
            check("callback signs in and redirects to next", r.status_code == 303 and r.headers["location"] == "/get",
                  (r.status_code, r.headers.get("location")))
            check("callback sets the session cookie", settings.SESSION_COOKIE_NAME in r.headers.get("set-cookie", ""))
            check("token request carries our client secret and the code",
                  SEEN["token_request"].get("client_secret") == "test-secret" and SEEN["token_request"].get("code") == "c1")
            db = SessionLocal(); u = db.query(User).filter(User.email == emails[0]).first(); db.close()
            check("account created with GitHub id, name and avatar",
                  u is not None and u.github_id == str(gid) and u.full_name == "Test Dev" and u.avatar.endswith(str(gid)))

            r = c.get(f"/auth/github/callback?code=c1&state={state}", follow_redirects=False)
            check("replayed state is rejected", r.headers["location"] == "/auth?github=failed")

            state, _ = start_web(c)
            c.cookies.clear(); c.cookies.set("github_oauth_state", "someone-elses-state", domain="testserver")
            r = c.get(f"/auth/github/callback?code=c2&state={state}", follow_redirects=False)
            check("state cookie mismatch (login CSRF) is rejected", r.headers["location"] == "/auth?github=failed")

            state, _ = start_web(c, "&lang=ru")
            r = c.get(f"/auth/github/callback?error=access_denied&state={state}", follow_redirects=False)
            check("cancel returns to the sign-in page in the same language",
                  r.headers["location"] == "/auth?lang=ru&github=cancelled", r.headers["location"])

            state, _ = start_web(c)
            GH["token_ok"] = False
            r = c.get(f"/auth/github/callback?code=bad&state={state}", follow_redirects=False)
            check("bad code (token exchange fails) is rejected", r.headers["location"] == "/auth?github=failed")

            # --- returning user keeps the same account even if the e-mail changed
            state, _ = start_web(c)
            set_github(gid, f"dev{tag}", emails[1])
            c.get(f"/auth/github/callback?code=c3&state={state}", follow_redirects=False)
            db = SessionLocal()
            n = db.query(User).filter(User.github_id == str(gid)).count()
            dup = db.query(User).filter(User.email == emails[1]).first()
            db.close()
            check("returning user matched by GitHub id (no duplicate)", n == 1 and dup is None)

            # --- linking an existing account by VERIFIED e-mail
            db = SessionLocal(); db.add(User(email=emails[2], full_name="Existing", role="parent")); db.commit()
            existing = db.query(User).filter(User.email == emails[2]).first().id; db.close()
            state, _ = start_web(c)
            set_github(base_id + 2, f"link{tag}", emails[2])
            c.get(f"/auth/github/callback?code=c4&state={state}", follow_redirects=False)
            db = SessionLocal(); linked = db.query(User).filter(User.email == emails[2]).first(); db.close()
            check("existing account linked by verified e-mail, keeps name and role",
                  linked.id == existing and linked.github_id == str(base_id + 2)
                  and linked.full_name == "Existing" and linked.role == "parent")

            # --- attack: victim's e-mail added UNVERIFIED to attacker's GitHub
            db = SessionLocal(); db.add(User(email=emails[3], full_name="Victim", role="parent")); db.commit(); db.close()
            state, _ = start_web(c)
            set_github(base_id + 3, f"att{tag}", emails[4],
                       extra_emails=({"email": emails[3], "primary": False, "verified": False},))
            c.get(f"/auth/github/callback?code=c5&state={state}", follow_redirects=False)
            db = SessionLocal()
            victim = db.query(User).filter(User.email == emails[3]).first()
            attacker = db.query(User).filter(User.github_id == str(base_id + 3)).first()
            db.close()
            check("unverified e-mail never takes over another account",
                  victim.github_id is None and attacker is not None and attacker.email == emails[4])

            state, _ = start_web(c)
            set_github(base_id + 4, f"nomail{tag}", emails[3], verified=False)
            r = c.get(f"/auth/github/callback?code=c6&state={state}", follow_redirects=False)
            db = SessionLocal(); victim = db.query(User).filter(User.email == emails[3]).first(); db.close()
            check("account with no verified e-mail is refused (no_email)",
                  r.headers["location"] == "/auth?github=no_email" and victim.github_id is None, r.headers["location"])

            # --- phone ticket flow
            check("app flow rejects a malformed nonce hash",
                  c.get("/auth/github/mobile?nonce_hash=xyz", follow_redirects=False).status_code == 400)
            raw = secrets.token_urlsafe(32)
            r = c.get(f"/auth/github/mobile?nonce_hash={github_auth.sha256_hex(raw)}", follow_redirects=False)
            mstate = parse_qs(urlparse(r.headers["location"]).query)["state"][0]
            set_github(base_id + 5, f"m{tag}", emails[5])
            r = c.get(f"/auth/github/callback?code=m1&state={mstate}", follow_redirects=False)
            loc = r.headers["location"]
            ticket = parse_qs(urlparse(loc).query).get("ticket", [""])[0]
            check("app flow returns a one-time ticket to nigohfamily://", loc.startswith("nigohfamily://auth/github?ticket=")
                  and len(ticket) > 20 and settings.SESSION_COOKIE_NAME not in r.headers.get("set-cookie", ""), loc)
            r = c.post("/api/mobile/v3/auth/github", json={"ticket": ticket, "nonce": raw})
            check("ticket + raw nonce gives a phone session", r.status_code == 200 and r.json()["token"].startswith("ngh_"),
                  (r.status_code, r.text[:100]))
            r = c.post("/api/mobile/v3/auth/github", json={"ticket": ticket, "nonce": raw})
            check("a ticket works only once", r.status_code == 401)

            r = c.get(f"/auth/github/mobile?nonce_hash={github_auth.sha256_hex(raw)}", follow_redirects=False)
            mstate = parse_qs(urlparse(r.headers["location"]).query)["state"][0]
            r = c.get(f"/auth/github/callback?code=m2&state={mstate}", follow_redirects=False)
            stolen = parse_qs(urlparse(r.headers["location"]).query)["ticket"][0]
            r = c.post("/api/mobile/v3/auth/github", json={"ticket": stolen, "nonce": "attacker-guess-0000000000"},
                       headers={"X-NIGOH-Lang": "ru"})
            check("intercepted ticket is useless without the app's nonce (translated error)",
                  r.status_code == 401 and r.json()["detail"] == "Вход через GitHub не подтверждён", r.text)

            old = github_auth.issue_ticket(1, github_auth.sha256_hex(raw))
            github_auth.TICKETS[old]["created_at"] -= settings.GITHUB_TICKET_MAX_AGE + 5
            r = c.post("/api/mobile/v3/auth/github", json={"ticket": old, "nonce": raw})
            check("expired ticket is rejected", r.status_code == 401)

            r = c.get(f"/auth/github/mobile?nonce_hash={github_auth.sha256_hex(raw)}", follow_redirects=False)
            mstate = parse_qs(urlparse(r.headers["location"]).query)["state"][0]
            r = c.get(f"/auth/github/callback?error=access_denied&state={mstate}", follow_redirects=False)
            check("app flow cancel goes back to the app", r.headers["location"] == "nigohfamily://auth/github?error=cancelled")
    finally:
        for k, v in saved.items():
            setattr(settings, k, v)
        github_auth.httpx.post, github_auth.httpx.get = real_post, real_get
        db = SessionLocal()
        ids = [u.id for u in db.query(User).filter(User.email.in_(emails)).all()]
        if ids:
            marks = ",".join(str(i) for i in ids)
            db.execute(text(f"DELETE FROM mobile_sessions WHERE user_id IN ({marks})"))
            db.execute(text(f"DELETE FROM users WHERE id IN ({marks})"))
            db.commit()
        db.close()
    print("All checks passed." if not FAILS else f"{len(FAILS)} check(s) failed.")
    _sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()
