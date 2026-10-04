"""Файл: санҷиши ҳимояи дуқабата — TOTP (векторҳои RFC 6238), рамзҳои эҳтиётӣ, қулф, чиптаҳо,
рамз ба почта ва ҳамаи маҳдудиятҳо барои сайт ва барнома."""

# Run from anywhere: make the project root importable and the working directory.
import os as _os, sys as _sys
_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

import uuid
from datetime import datetime, timedelta, timezone

from cryptography.fernet import Fernet
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
from app.core import otp
from app.core.config import settings
from app.core.security import hash_password, rate_limiter
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models.email_code import EmailCode
from app.models.user import User

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


def make_user(db, email: str, role: str = "parent", password: str = "goodpass1") -> User:
    """Корбари навро бо парол месозад."""
    user = User(email=email, full_name="Тест", role=role, password_hash=hash_password(password))
    db.add(user)
    db.commit()
    return user


def code_for(secret: str, offset: int = 0) -> str:
    """Рамзи TOTP-и ҳозира (ё қадами ҳамсоя)."""
    return otp.totp_at(secret, otp.current_step() + offset)


def unit_checks() -> None:
    """Функсияҳои тозаи TOTP аз рӯи RFC 6238 (SHA1, 6 рақами охир)."""
    rfc = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"  # «12345678901234567890»
    for t, want in ((59, "287082"), (1111111109, "081804"), (1111111111, "050471"),
                    (1234567890, "005924"), (2000000000, "279037"), (20000000000, "353130")):
        check(f"RFC 6238 vector T={t}", otp.totp_at(rfc, t // 30) == want, otp.totp_at(rfc, t // 30))
    s = otp.new_secret()
    check("secret is 32 base32 chars", len(s) == 32 and s.isalnum())
    now = 1_700_000_000
    step = now // 30
    check("current code accepted", otp.match_totp(s, otp.totp_at(s, step), None, at=now) == step)
    check("previous step accepted (clock skew)", otp.match_totp(s, otp.totp_at(s, step - 1), None, at=now) == step - 1)
    check("two steps old rejected", otp.match_totp(s, otp.totp_at(s, step - 2), None, at=now) is None)
    check("replay rejected", otp.match_totp(s, otp.totp_at(s, step), step, at=now) is None)
    check("letters rejected", otp.match_totp(s, "12a456", None, at=now) is None)
    check("spaces ignored", otp.match_totp(s, otp.totp_at(s, step)[:3] + " " + otp.totp_at(s, step)[3:], None, at=now) == step)
    uri = otp.otpauth_uri(s, "a@b.tj")
    check("otpauth uri", uri.startswith("otpauth://totp/NIGOH%20Family%3Aa%40b.tj?secret=") and "issuer=NIGOH%20Family" in uri, uri)
    check("qr is png data uri", otp.qr_data_uri(uri).startswith("data:image/png;base64,"))
    check("message ru with minutes", otp.message(otp.OtpError("locked", 61), "ru").endswith("(2 мин)"))
    check("message en cooldown seconds", otp.message(otp.OtpError("cooldown", 5), "en").endswith("(5 s)"))


def api_checks() -> None:
    """Аз фаъол кардан то қулф тавассути API-и сайт ва барнома."""
    app.dependency_overrides[get_db] = override_db
    sent = []
    original_sender = otp.send_email
    otp.send_email = lambda to, code: sent.append((to, code))
    saved = (settings.OTP_ENCRYPTION_KEY, settings.SMTP_HOST, settings.SMTP_FROM)
    db = Session()
    try:
        c = TestClient(app)
        s = uuid.uuid4().hex[:6]

        # --- бе калид: TOTP хомӯш, бе SMTP: почта хомӯш
        settings.OTP_ENCRYPTION_KEY, settings.SMTP_HOST, settings.SMTP_FROM = "", "", ""
        check("config off", c.get("/api/auth/otp/config").json() == {"totp": False, "email": False})
        r = c.post("/api/auth/email-code", json={"email": "x@y.tj"})
        check("email code without SMTP -> 503", r.status_code == 503, str(r.status_code))
        settings.OTP_ENCRYPTION_KEY = Fernet.generate_key().decode()
        settings.SMTP_HOST, settings.SMTP_FROM = "smtp.test", "NIGOH <no-reply@test>"
        check("config on", c.get("/api/mobile/v3/auth/otp/config").json() == {"totp": True, "email": True})

        # --- корбари мобилӣ: фаъол кардани Authenticator
        reg = c.post("/api/mobile/v3/auth/register", json={"email": f"otp{s}@example.com", "password": "parentpass1", "full_name": "Падар"}).json()
        H = {"Authorization": f"Bearer {reg['token']}", "X-NIGOH-Role": "parent"}
        check("status before setup", c.get("/api/mobile/v3/me/totp", headers=H).json() == {"available": True, "enabled": False, "recovery_left": 0})
        setup = c.post("/api/mobile/v3/me/totp/setup", headers=H).json()
        secret = setup["secret"]
        check("setup returns qr and uri", setup["qr"].startswith("data:image/png") and secret in setup["uri"])
        user = db.query(User).filter(User.email == f"otp{s}@example.com").one()
        check("secret stored encrypted", user.totp_secret_enc and secret not in user.totp_secret_enc)
        check("not enabled until confirmed", not user.totp_enabled)
        r = c.post("/api/mobile/v3/me/totp/confirm", json={"code": "000000"}, headers=H)
        check("wrong confirm code -> 400", r.status_code == 400)
        r = c.post("/api/mobile/v3/me/totp/confirm", json={"code": code_for(secret)}, headers=H)
        check("confirm -> enabled", r.status_code == 200 and r.json()["enabled"], r.text)
        recovery = r.json()["recovery_codes"]
        check("8 recovery codes", len(recovery) == 8 and all(len(x) == 9 and x[4] == "-" for x in recovery))
        db.expire_all()
        check("recovery codes stored as hashes", all(code not in (user.recovery_codes_json or "") for code in recovery))
        check("setup again refused", c.post("/api/mobile/v3/me/totp/setup", headers=H).status_code == 400)

        # --- воридшавӣ дар барнома: чипта → рамз
        login = {"email": f"otp{s}@example.com", "password": "parentpass1"}
        r = c.post("/api/mobile/v3/auth/login", json=login)
        check("password login asks for code", r.json().get("status") == "otp_required" and "token" not in r.json(), r.text)
        ticket = r.json()["ticket"]
        r = c.post("/api/mobile/v3/auth/login/otp", json={"ticket": ticket, "code": code_for(secret)})
        check("same code as confirm is a replay -> 400", r.status_code == 400, r.text)
        # Рамзи қадами навбатӣ (дар ±1 қадам) — дуруст ва нав.
        r = c.post("/api/mobile/v3/auth/login/otp", json={"ticket": ticket, "code": code_for(secret, 1)})
        check("next-step code gives a token", r.status_code == 200 and r.json()["token"].startswith("ngh_"), r.text)
        r = c.post("/api/mobile/v3/auth/login/otp", json={"ticket": ticket, "code": code_for(secret, 1)})
        check("ticket is single-use", r.status_code == 401)

        # --- рамзи эҳтиётӣ (якдафъаина) ва бе тире
        ticket = c.post("/api/mobile/v3/auth/login", json=login).json()["ticket"]
        r = c.post("/api/mobile/v3/auth/login/otp", json={"ticket": ticket, "code": recovery[0].replace("-", "").lower()})
        check("recovery code works (any case, no dash)", r.status_code == 200, r.text)
        ticket = c.post("/api/mobile/v3/auth/login", json=login).json()["ticket"]
        r = c.post("/api/mobile/v3/auth/login/otp", json={"ticket": ticket, "code": recovery[0]})
        check("recovery code cannot be reused", r.status_code == 400)
        check("7 recovery codes left", c.get("/api/mobile/v3/me/totp", headers=H).json()["recovery_left"] == 7)

        # --- қулф: 5 рамзи нодуруст → 429, чипта беэътибор
        db.expire_all(); user = db.get(User, user.id); user.otp_failed = 0; db.commit()
        ticket = c.post("/api/mobile/v3/auth/login", json=login).json()["ticket"]
        codes = [c.post("/api/mobile/v3/auth/login/otp", json={"ticket": ticket, "code": "111111"}, headers={"X-NIGOH-Lang": "en"}).status_code for _ in range(5)]
        check("four wrong codes 400, fifth locks", codes[:4] == [400] * 4 and codes[4] == 429, str(codes))
        r = c.post("/api/mobile/v3/auth/login", json=login, headers={"X-NIGOH-Lang": "ru"})
        check("password login refused while locked", r.status_code == 429 and "заблокирован" in r.json()["detail"], r.text)
        db.expire_all(); user = db.get(User, user.id)
        check("lock lasts 15 minutes", 14 * 60 < (user.otp_locked_until - _utcnow()).total_seconds() <= 15 * 60)
        user.otp_locked_until = _utcnow() - timedelta(seconds=1); db.commit()
        r = c.post("/api/mobile/v3/auth/login", json=login)
        check("after the lock the account works again", r.json().get("status") == "otp_required")

        # --- хомӯш кардан бо рамз
        r = c.post("/api/mobile/v3/me/totp/disable", json={"code": "123123"}, headers=H)
        check("disable needs a valid code", r.status_code == 400)
        r = c.post("/api/mobile/v3/me/totp/disable", json={"code": recovery[1]}, headers=H)
        check("disable with recovery code", r.status_code == 200 and not r.json()["enabled"], r.text)
        r = c.post("/api/mobile/v3/auth/login", json=login)
        check("login without code after disable", "token" in r.json(), r.text)

        # --- қулф барои паролҳои нодуруст (бе OTP ҳам)
        rate_limiter._history.clear()
        db.expire_all(); user = db.get(User, user.id); user.otp_failed = 0; user.otp_locked_until = None; db.commit()
        codes = [c.post("/api/mobile/v3/auth/login", json={**login, "password": "wrong"}).status_code for _ in range(5)]
        check("5 wrong passwords then lock", codes == [400] * 5, str(codes))
        r = c.post("/api/mobile/v3/auth/login", json=login)
        check("right password refused while locked", r.status_code == 429)
        db.expire_all(); user = db.get(User, user.id); user.otp_locked_until = None; db.commit()

        # --- сайт: воридшавӣ бо Authenticator
        rate_limiter._history.clear()
        web_user = make_user(db, f"web{s}@example.com")
        wc = TestClient(app)
        check("security page needs sign-in", wc.get("/account/security", follow_redirects=False).status_code == 303)
        r = wc.post("/api/auth/login", json={"email": f"WEB{s}@example.com", "password": "goodpass1"})
        check("web login (case-insensitive email)", r.status_code == 200 and r.json()["status"] == "success", r.text)
        page = wc.get("/account/security")
        check("security page renders", page.status_code == 200 and "account-security" in page.text and "{{" not in page.text)
        secret2 = wc.post("/api/account/totp/setup").json()["secret"]
        r = wc.post("/api/account/totp/confirm", json={"code": code_for(secret2)})
        check("web confirm", r.status_code == 200 and len(r.json()["recovery_codes"]) == 8)
        web_recovery = r.json()["recovery_codes"]
        c2 = TestClient(app)
        r = c2.post("/api/auth/login", json={"email": f"web{s}@example.com", "password": "goodpass1"})
        check("web password login asks for code", r.json()["status"] == "otp_required" and "session_token" not in r.cookies)
        r = c2.post("/api/auth/login/otp", json={"ticket": r.json()["ticket"], "code": code_for(secret2, 1)})
        check("web code sets the session cookie", r.status_code == 200 and "session_token" in r.cookies, r.text)
        check("signed in after code", c2.get("/api/account/totp").json()["enabled"])
        check("unauthenticated status -> 401", TestClient(app).get("/api/account/totp").status_code == 401)
        r = wc.post("/api/account/totp/disable", json={"code": code_for(secret2, -1)})
        check("older code after a newer one is a replay", r.status_code == 400)
        r = wc.post("/api/account/totp/disable", json={"code": web_recovery[0]})
        check("web disable closes other sessions", r.status_code == 200 and c2.get("/api/account/totp").status_code == 401, r.text)

        # --- рамз ба почта
        rate_limiter._history.clear()
        r = c.post("/api/auth/email-code", json={"email": f"web{s}@example.com"})
        check("email code sent", r.status_code == 200 and sent and sent[-1][0] == f"web{s}@example.com", r.text)
        code = sent[-1][1]
        check("6 digit code", len(code) == 6 and code.isdigit())
        row = db.query(EmailCode).filter(EmailCode.email == f"web{s}@example.com").order_by(EmailCode.id.desc()).first()
        check("code stored as hash", row.code_hash != code and len(row.code_hash) == 64)
        r = c.post("/api/auth/email-code", json={"email": f"web{s}@example.com"}, headers={"X-NIGOH-Lang": "en"})
        check("cooldown 60 s", r.status_code == 429 and "wait" in r.json()["detail"] and r.headers.get("retry-after"), r.text)
        bad = [c.post("/api/auth/email-code/verify", json={"email": f"web{s}@example.com", "code": "000000" if code != "000000" else "111111"}).status_code for _ in range(5)]
        check("5 wrong email codes", bad == [400] * 5, str(bad))
        r = c.post("/api/auth/email-code/verify", json={"email": f"web{s}@example.com", "code": code})
        check("code dead after 5 attempts", r.status_code == 401, r.text)
        db.query(EmailCode).update({EmailCode.created_at: _utcnow() - timedelta(minutes=2)}); db.commit()
        c.post("/api/auth/email-code", json={"email": f"web{s}@example.com"})
        code = sent[-1][1]
        r = c.post("/api/auth/email-code/verify", json={"email": f"web{s}@example.com", "code": code})
        check("right email code signs in", r.status_code == 200 and r.json()["status"] == "success" and "session_token" in r.cookies, r.text)
        r = c.post("/api/auth/email-code/verify", json={"email": f"web{s}@example.com", "code": code})
        check("email code single use", r.status_code == 401)
        db.query(EmailCode).update({EmailCode.created_at: _utcnow() - timedelta(minutes=2)}); db.commit()
        c.post("/api/auth/email-code", json={"email": f"web{s}@example.com"})
        r = c.post("/api/auth/email-code", json={"email": f"web{s}@example.com"})
        db.query(EmailCode).update({EmailCode.created_at: _utcnow() - timedelta(minutes=5)}); db.commit()
        r = c.post("/api/auth/email-code", json={"email": f"web{s}@example.com"})
        check("max 3 codes per hour", r.status_code == 429 and "Рамзҳои зиёд" in r.json()["detail"], r.text)
        n = len(sent)
        r = c.post("/api/auth/email-code", json={"email": f"nobody{s}@example.com"})
        check("unknown email: same answer, nothing sent", r.status_code == 200 and len(sent) == n)
        r = c.post("/api/auth/email-code/verify", json={"email": f"nobody{s}@example.com", "code": "123456"})
        check("unknown email cannot sign in", r.status_code == 401)
        # Мӯҳлат: рамзи кӯҳна кор намекунад.
        db.query(EmailCode).delete(); db.commit()
        c.post("/api/auth/email-code", json={"email": f"otp{s}@example.com"})
        code = sent[-1][1]
        db.query(EmailCode).update({EmailCode.expires_at: _utcnow() - timedelta(seconds=1)}); db.commit()
        r = c.post("/api/mobile/v3/auth/email-code/verify", json={"email": f"otp{s}@example.com", "code": code})
        check("expired email code refused", r.status_code == 401)
        db.query(EmailCode).delete(); db.commit()
        c.post("/api/mobile/v3/auth/email-code", json={"email": f"otp{s}@example.com"})
        r = c.post("/api/mobile/v3/auth/email-code/verify", json={"email": f"otp{s}@example.com", "code": sent[-1][1]})
        check("mobile email code gives a token", r.status_code == 200 and "token" in r.json(), r.text)
        # Почта + Authenticator: баъди рамзи почта қадами дуюм лозим аст.
        db.expire_all()
        u = db.query(User).filter(User.email == f"otp{s}@example.com").one()
        sec3 = otp.begin_setup(u); db.commit()
        otp.confirm_setup(db, u, code_for(sec3["secret"])); db.commit()
        db.query(EmailCode).delete(); db.commit()
        c.post("/api/mobile/v3/auth/email-code", json={"email": f"otp{s}@example.com"})
        r = c.post("/api/mobile/v3/auth/email-code/verify", json={"email": f"otp{s}@example.com", "code": sent[-1][1]})
        check("email code + authenticator asks for second factor", r.json().get("status") == "otp_required" and "token" not in r.json(), r.text)

        # --- админ: барнома рад мекунад, сайт бо OTP
        admin = make_user(db, f"admin{s}@example.com", role="admin")
        r = c.post("/api/mobile/v3/auth/login", json={"email": f"admin{s}@example.com", "password": "goodpass1"})
        check("admin cannot use the app", r.status_code == 403)
    finally:
        otp.send_email = original_sender
        settings.OTP_ENCRYPTION_KEY, settings.SMTP_HOST, settings.SMTP_FROM = saved
        app.dependency_overrides.clear()
        rate_limiter._history.clear()
        db.close()


if __name__ == "__main__":
    unit_checks()
    api_checks()
    print(f"\nALL {PASSED} CHECKS PASSED")
