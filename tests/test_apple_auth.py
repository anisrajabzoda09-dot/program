"""Файл: санҷишҳои автоматии `test_apple_auth` ва сенарияҳои ёрирасони он."""
# Run from anywhere: make the project root importable and the working directory.
import os as _os, sys as _sys
_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

import json
import time
import uuid
from urllib.parse import parse_qs, urlparse

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from fastapi.testclient import TestClient

from app.core import apple_auth
from app.core.config import settings
from app.db.session import SessionLocal
from app.main import app
from app.models.user import User

FAILS = []


def check(label, ok, detail=""):
    """Натиҷаи санҷишро сабт карда, нокомиро барои ҷамъбаст нигоҳ медорад."""
    print(f"{'ok ' if ok else 'FAIL'} {label}{(' — ' + str(detail)) if detail and not ok else ''}")
    if not ok:
        FAILS.append(label)


EC_KEY = ec.generate_private_key(ec.SECP256R1())
RSA_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)
EC_PEM = EC_KEY.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                              serialization.NoEncryption()).decode()


class _Key:
    """Муҳити ёрирасони `_Key`-ро барои санҷиш фароҳам мекунад."""
    key = RSA_KEY.public_key()


class _FakeJwks:
    """Муҳити ёрирасони `_FakeJwks`-ро барои санҷиш фароҳам мекунад."""
    def get_signing_key_from_jwt(self, token):
        """Рафтори `get_signing_key_from_jwt`-ро дар муҳити санҷишӣ месанҷад."""
        return _Key()


def apple_token(sub, email, aud=None, nonce=None, exp_in=600, email_verified="true"):
    """Рафтори `apple_token`-ро дар муҳити санҷишӣ месанҷад."""
    now = int(time.time())
    claims = {"iss": settings.APPLE_ISSUER, "aud": aud or settings.APPLE_CLIENT_ID, "sub": sub,
              "iat": now, "exp": now + exp_in, "email": email, "email_verified": email_verified}
    if nonce is not None:
        claims["nonce"] = nonce
    return jwt.encode(claims, RSA_KEY, algorithm="RS256", headers={"kid": "test"})


class _Resp:
    """Муҳити ёрирасони `_Resp`-ро барои санҷиш фароҳам мекунад."""
    def __init__(self, payload, status=200):
        """Рафтори `__init__`-ро дар муҳити санҷишӣ месанҷад."""
        self._p, self.status_code = payload, status

    def json(self):
        """Рафтори `json`-ро дар муҳити санҷишӣ месанҷад."""
        return self._p


NEXT_TOKEN = {}


def fake_post(url, data=None, **kw):
    """Рафтори `fake_post`-ро дар муҳити санҷишӣ месанҷад."""
    secret = jwt.decode(data["client_secret"], EC_KEY.public_key(), algorithms=["ES256"],
                        audience=settings.APPLE_ISSUER)
    assert secret["iss"] == settings.APPLE_TEAM_ID and secret["sub"] == settings.APPLE_CLIENT_ID
    return _Resp({"id_token": NEXT_TOKEN["value"]})


def login_and_get_state(c, lang=""):
    """Рафтори `login_and_get_state`-ро дар муҳити санҷишӣ месанҷад."""
    r = c.get(f"/auth/apple/login?next=%2Fget{lang}", follow_redirects=False)
    q = parse_qs(urlparse(r.headers["location"]).query)
    return q.get("state", [""])[0], q.get("nonce", [""])[0], r


def main():
    """Ҳамаи сенарияҳои санҷиширо иҷро карда, додаҳои муваққатиро пок мекунад."""
    tag = uuid.uuid4().hex[:8]
    emails = [f"qa_apple_{tag}@example.com", f"qa_apple_relay_{tag}@privaterelay.appleid.com",
              f"qa_apple_link_{tag}@example.com", f"qa_apple_m_{tag}@example.com"]
    saved = {k: getattr(settings, k) for k in ("APPLE_CLIENT_ID", "APPLE_TEAM_ID", "APPLE_KEY_ID",
                                                "APPLE_PRIVATE_KEY", "APPLE_PRIVATE_KEY_PATH")}
    real_post, real_jwks = apple_auth.httpx.post, apple_auth._jwks_client
    try:
        with TestClient(app, base_url="https://testserver") as c:
            # --- not configured: hidden button, refusing routes
            for k in saved:
                setattr(settings, k, "")
            check("not configured: login redirects to the notice",
                  c.get("/auth/apple/login", follow_redirects=False).headers["location"] == "/auth?apple=not_configured")
            check("not configured: no Apple button", 'id="appleSignInBtn"' not in c.get("/auth").text)
            r = c.post("/api/mobile/v3/auth/apple", json={"identity_token": "x" * 30, "nonce": "n" * 20})
            check("not configured: mobile API refuses (503)", r.status_code == 503, r.status_code)
            check("not configured: app config says disabled",
                  c.get("/api/mobile/v3/auth/apple/config").json() == {"enabled": False, "client_id": None, "redirect_uri": None})

            # --- configure with test keys
            settings.APPLE_CLIENT_ID, settings.APPLE_TEAM_ID, settings.APPLE_KEY_ID = "tj.nigoh.web", "TEAM123456", "KEY1234567"
            settings.APPLE_PRIVATE_KEY = EC_PEM
            apple_auth.httpx.post = fake_post
            apple_auth._jwks_client = lambda: _FakeJwks()

            cfg = c.get("/api/mobile/v3/auth/apple/config").json()
            check("app config: enabled, Services ID, Android bridge URL, no secrets",
                  cfg == {"enabled": True, "client_id": "tj.nigoh.web",
                          "redirect_uri": "https://nigohfamily.qobus.tj/auth/apple/android"}, cfg)
            for path, label in (("/auth", "Идома бо Apple"), ("/auth?lang=ru", "Продолжить с Apple"),
                                ("/auth?lang=en", "Continue with Apple")):
                html = c.get(path).text
                check(f"button shown with label: {label}", 'id="appleSignInBtn"' in html and label in html)

            secret = apple_auth.client_secret()
            hdr = jwt.get_unverified_header(secret)
            dec = jwt.decode(secret, EC_KEY.public_key(), algorithms=["ES256"], audience=settings.APPLE_ISSUER)
            check("client secret: ES256, kid, team, services id",
                  hdr["alg"] == "ES256" and hdr["kid"] == "KEY1234567" and dec["iss"] == "TEAM123456"
                  and dec["sub"] == "tj.nigoh.web" and dec["exp"] - dec["iat"] <= 600)

            state, nonce, r = login_and_get_state(c)
            loc = urlparse(r.headers["location"]); q = parse_qs(loc.query)
            cookie = r.headers.get("set-cookie", "").lower()
            check("login redirects to Apple with form_post, name+email scope, state and nonce",
                  loc.netloc == "appleid.apple.com" and q["response_mode"] == ["form_post"]
                  and q["scope"] == ["name email"] and len(state) > 20 and len(nonce) > 20)
            check("state cookie is SameSite=None + Secure (needed for Apple's POST back)",
                  "apple_oauth_state=" in cookie and "samesite=none" in cookie and "secure" in cookie, cookie)

            # --- happy path, first sign-in with name
            sub1 = f"001234.{tag}.0001"
            NEXT_TOKEN["value"] = apple_token(sub1, emails[0], nonce=nonce)
            user_json = json.dumps({"name": {"firstName": "Test", "lastName": "Person"}})
            r = c.post("/auth/apple/callback", data={"code": "c1", "state": state, "user": user_json},
                       follow_redirects=False)
            check("callback signs in and redirects to next", r.status_code == 303 and r.headers["location"] == "/get",
                  (r.status_code, r.headers.get("location")))
            check("callback sets the session cookie", settings.SESSION_COOKIE_NAME in r.headers.get("set-cookie", ""))
            db = SessionLocal()
            u = db.query(User).filter(User.email == emails[0]).first()
            check("account created with apple_id and the name from Apple",
                  u is not None and u.apple_id == sub1 and u.full_name == "Test Person")
            first_id = u.id if u else None
            db.close()

            # --- state is single-use
            r = c.post("/auth/apple/callback", data={"code": "c1", "state": state}, follow_redirects=False)
            check("replayed state is rejected", r.headers["location"] == "/auth?apple=failed")

            # --- second sign-in: same Apple id, private relay email -> same account
            state, nonce, _ = login_and_get_state(c)
            NEXT_TOKEN["value"] = apple_token(sub1, emails[1], nonce=nonce)
            r = c.post("/auth/apple/callback", data={"code": "c2", "state": state}, follow_redirects=False)
            db = SessionLocal()
            n = db.query(User).filter(User.apple_id == sub1).count()
            relay = db.query(User).filter(User.email == emails[1]).first()
            db.close()
            check("returning user matched by Apple id (no duplicate account)",
                  r.status_code == 303 and n == 1 and relay is None)

            # --- attacks / failures
            state, nonce, _ = login_and_get_state(c)
            # The victim's browser holds a different state cookie than the one in the POST.
            c.cookies.clear()
            c.cookies.set("apple_oauth_state", "someone-elses-state", domain="testserver")
            NEXT_TOKEN["value"] = apple_token(sub1, emails[0], nonce=nonce)
            r = c.post("/auth/apple/callback", data={"code": "c3", "state": state}, follow_redirects=False)
            check("state cookie mismatch (login CSRF) is rejected", r.headers["location"] == "/auth?apple=failed")

            state, nonce, _ = login_and_get_state(c)
            NEXT_TOKEN["value"] = apple_token(sub1, emails[0], nonce="attacker-nonce-value-123")
            r = c.post("/auth/apple/callback", data={"code": "c4", "state": state}, follow_redirects=False)
            check("token with a foreign nonce is rejected", r.headers["location"] == "/auth?apple=failed")

            state, nonce, _ = login_and_get_state(c)
            NEXT_TOKEN["value"] = apple_token(sub1, emails[0], aud="com.other.app", nonce=nonce)
            r = c.post("/auth/apple/callback", data={"code": "c5", "state": state}, follow_redirects=False)
            check("token issued for another app is rejected", r.headers["location"] == "/auth?apple=failed")

            state, _, _ = login_and_get_state(c, "&lang=ru")
            r = c.post("/auth/apple/callback", data={"state": state, "error": "user_cancelled_authorize"},
                       follow_redirects=False)
            check("cancel returns to the sign-in page in the same language",
                  r.headers["location"] == "/auth?lang=ru&apple=cancelled", r.headers["location"])

            # --- linking to an existing email account (verified email)
            db = SessionLocal()
            db.add(User(email=emails[2], full_name="Existing", role="parent")); db.commit()
            existing_id = db.query(User).filter(User.email == emails[2]).first().id
            db.close()
            state, nonce, _ = login_and_get_state(c)
            sub2 = f"001234.{tag}.0002"
            NEXT_TOKEN["value"] = apple_token(sub2, emails[2], nonce=nonce)
            c.post("/auth/apple/callback", data={"code": "c6", "state": state}, follow_redirects=False)
            db = SessionLocal()
            linked = db.query(User).filter(User.email == emails[2]).first()
            db.close()
            check("existing email account gets linked, keeps its name and role",
                  linked.id == existing_id and linked.apple_id == sub2 and linked.full_name == "Existing"
                  and linked.role == "parent")

            # --- mobile API (nonce hashed by the app, as the Flutter plugin does)
            raw = "raw-nonce-" + tag + "-xxxxxxxx"
            sub3 = f"001234.{tag}.0003"
            tok = apple_token(sub3, emails[3], nonce=apple_auth.nonce_hash(raw))
            r = c.post("/api/mobile/v3/auth/apple", json={"identity_token": tok, "nonce": raw, "full_name": "Phone User"})
            check("mobile: valid token issues a session", r.status_code == 200 and r.json().get("token", "").startswith("ngh_"),
                  (r.status_code, r.text[:120]))
            r = c.post("/api/mobile/v3/auth/apple", json={"identity_token": tok, "nonce": "wrong-nonce-0000000000"},
                       headers={"X-NIGOH-Lang": "ru"})
            check("mobile: wrong nonce rejected with a translated message",
                  r.status_code == 401 and r.json()["detail"] == "Вход через Apple не подтверждён", r.text)
            expired = apple_token(sub3, emails[3], nonce=apple_auth.nonce_hash(raw), exp_in=-60)
            r = c.post("/api/mobile/v3/auth/apple", json={"identity_token": expired, "nonce": raw})
            check("mobile: expired token rejected", r.status_code == 401, r.status_code)

            # --- Android bridge forwards only Apple's fields to our package
            r = c.post("/auth/apple/android", data={"code": "abc", "id_token": "t", "state": "s", "evil": "x"},
                       follow_redirects=False)
            loc = r.headers.get("location", "")
            check("android bridge: intent to our package, unknown fields dropped",
                  loc.startswith("intent://callback?") and "package=tj.nigoh.nigoh_family_parent;" in loc
                  and "evil" not in loc and "code=abc" in loc)
    finally:
        for k, v in saved.items():
            setattr(settings, k, v)
        apple_auth.httpx.post, apple_auth._jwks_client = real_post, real_jwks
        db = SessionLocal()
        ids = [u.id for u in db.query(User).filter(User.email.in_(emails)).all()]
        from sqlalchemy import text
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
