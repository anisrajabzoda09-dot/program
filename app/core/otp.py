"""Файл: ҳимояи дуқабата (OTP) — Authenticator (TOTP, RFC 6238), рамзҳои эҳтиётӣ, рамз ба почта
ва маҳдудиятҳо: қулф пас аз 5 кӯшиш, мӯҳлати рамз, зидди такрор ва ҳадди фиристодан.

Ҳамаи рамзҳо дар база танҳо ҳамчун hash нигоҳ дошта мешаванд; калиди Authenticator бо Fernet
(OTP_ENCRYPTION_KEY) рамзгузорӣ мешавад. Рамзҳо бо hmac.compare_digest муқоиса мешаванд.
"""

import base64
import hashlib
import hmac
import io
import json
import secrets
import smtplib
import struct
import threading
import time
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
from typing import Optional
from urllib.parse import quote

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.email_code import EmailCode
from app.models.user import User

STEP = 30                # дарозии як қадами TOTP (сония)
DIGITS = 6
WINDOW = 1               # ±1 қадам барои фарқи соати телефон
RECOVERY_COUNT = 8

# Чиптаҳои «парол дуруст, акнун рамз»: ticket → {user_id, expires, attempts, channel}.
_TICKETS: dict = {}
_TICKETS_LOCK = threading.Lock()


class OtpError(Exception):
    """Хатои OTP бо калиди кӯтоҳ (масалан «locked», «invalid») ва вақти боқимонда."""

    def __init__(self, code: str, retry_after: int = 0):
        """Калиди хато ва сонияҳо то кӯшиши навбатиро нигоҳ медорад."""
        super().__init__(code)
        self.code = code
        self.retry_after = retry_after


# ---------------------------------------------------------------- рамзгузорӣ

def totp_available() -> bool:
    """Authenticator танҳо вақте кор мекунад, ки калиди рамзгузорӣ дар сервер гузошта шудааст."""
    return bool(_fernet())


def email_available() -> bool:
    """Рамз ба почта танҳо бо SMTP-и танзимшуда кор мекунад."""
    return bool(settings.SMTP_HOST and settings.SMTP_FROM)


def _fernet():
    """Объекти Fernet аз OTP_ENCRYPTION_KEY ё None, агар калид нест ё нодуруст аст."""
    key = (settings.OTP_ENCRYPTION_KEY or "").strip()
    if not key:
        return None
    try:
        from cryptography.fernet import Fernet
        return Fernet(key.encode("ascii"))
    except Exception:
        return None


def _encrypt(secret: str) -> str:
    """Калиди Authenticator-ро барои база рамзгузорӣ мекунад."""
    f = _fernet()
    if f is None:
        raise OtpError("unavailable")
    return f.encrypt(secret.encode("ascii")).decode("ascii")


def _decrypt(token: str) -> Optional[str]:
    """Калиди Authenticator-ро аз база мекушояд; хато бошад, None."""
    f = _fernet()
    if f is None or not token:
        return None
    try:
        return f.decrypt(token.encode("ascii")).decode("ascii")
    except Exception:
        return None


def _sha256(text: str) -> str:
    """Hash-и SHA-256 барои рамзҳои эҳтиётӣ ва рамзҳои почта."""
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _now() -> datetime:
    """Вақти ҳозира бе минтақа (UTC) — ҳамон тавре ки SQLite нигоҳ медорад."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _naive(value: Optional[datetime]) -> Optional[datetime]:
    """Вақтро ба UTC-и бе минтақа меорад."""
    if value is None:
        return None
    if value.tzinfo is not None:
        value = value.astimezone(timezone.utc).replace(tzinfo=None)
    return value


# ---------------------------------------------------------------- TOTP (RFC 6238)

def new_secret() -> str:
    """Калиди нави тасодуфӣ (160 бит) бо base32 барои Authenticator."""
    return base64.b32encode(secrets.token_bytes(20)).decode("ascii").rstrip("=")


def _b32(secret: str) -> bytes:
    """Base32-ро бо padding-и лозимӣ мекушояд."""
    clean = secret.strip().replace(" ", "").upper()
    return base64.b32decode(clean + "=" * (-len(clean) % 8))


def totp_at(secret: str, step: int) -> str:
    """Рамзи 6-рақамаи TOTP барои рақами қадам (HMAC-SHA1, RFC 4226/6238)."""
    digest = hmac.new(_b32(secret), struct.pack(">Q", step), hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    number = struct.unpack(">I", digest[offset:offset + 4])[0] & 0x7FFFFFFF
    return str(number % (10 ** DIGITS)).zfill(DIGITS)


def current_step(at: Optional[float] = None) -> int:
    """Рақами қадами ҳозираи 30-сонияӣ."""
    return int((time.time() if at is None else at) // STEP)


def match_totp(secret: str, code: str, last_step: Optional[int], at: Optional[float] = None) -> Optional[int]:
    """Агар рамз дар ±1 қадам дуруст бошад ва пештар истифода нашуда бошад, қадамро бармегардонад."""
    code = (code or "").strip().replace(" ", "")
    if len(code) != DIGITS or not code.isdigit():
        return None
    now = current_step(at)
    for step in range(now - WINDOW, now + WINDOW + 1):
        if last_step is not None and step <= last_step:
            continue  # зидди такрор: ҳамон рамз ду бор қабул намешавад
        if hmac.compare_digest(totp_at(secret, step), code):
            return step
    return None


def otpauth_uri(secret: str, account: str) -> str:
    """Суроғаи otpauth:// барои QR дар Google Authenticator ва барномаҳои монанд."""
    issuer = settings.OTP_ISSUER
    label = quote(f"{issuer}:{account}")
    return f"otpauth://totp/{label}?secret={secret}&issuer={quote(issuer)}&algorithm=SHA1&digits={DIGITS}&period={STEP}"


def qr_data_uri(text: str) -> str:
    """Рамзи QR-ро ҳамчун тасвири PNG дар data: URI месозад (бе файл ва бе хидмати беруна)."""
    import qrcode
    img = qrcode.make(text, box_size=6, border=2)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


# ---------------------------------------------------------------- фаъол / хомӯш кардан

def begin_setup(user: User) -> dict:
    """Калиди навро месозад ва нигоҳ медорад (ҳоло хомӯш). Барои QR ва дастӣ бармегардонад."""
    if not totp_available():
        raise OtpError("unavailable")
    if user.totp_enabled:
        raise OtpError("already_enabled")
    secret = new_secret()
    user.totp_secret_enc = _encrypt(secret)
    user.totp_last_step = None
    uri = otpauth_uri(secret, user.email)
    return {"secret": secret, "uri": uri, "qr": qr_data_uri(uri)}


def _new_recovery_codes() -> list:
    """8 рамзи эҳтиётии якдафъаина, масалан «7KQ2-M9XD»."""
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return ["".join(secrets.choice(alphabet) for _ in range(4)) + "-" + "".join(secrets.choice(alphabet) for _ in range(4))
            for _ in range(RECOVERY_COUNT)]


def _normalize_recovery(code: str) -> str:
    """Рамзи эҳтиётиро бе фосила ва бо ҳарфҳои калон меорад."""
    clean = (code or "").strip().upper().replace(" ", "").replace("-", "")
    return f"{clean[:4]}-{clean[4:]}" if len(clean) == 8 else clean


def confirm_setup(db: Session, user: User, code: str) -> list:
    """Аввалин рамзро месанҷад, TOTP-ро фаъол мекунад ва рамзҳои эҳтиётиро (як бор) бармегардонад."""
    check_not_locked(user)
    secret = _decrypt(user.totp_secret_enc or "")
    if user.totp_enabled or not secret:
        raise OtpError("no_setup")
    step = match_totp(secret, code, user.totp_last_step)
    if step is None:
        raise _invalid(db, user)
    codes = _new_recovery_codes()
    user.totp_enabled = 1
    user.totp_last_step = step
    user.recovery_codes_json = json.dumps([_sha256(c) for c in codes])
    reset_failures(user)
    return codes


def disable(db: Session, user: User, code: str) -> None:
    """Ҳимояи дуқабатаро бо рамзи ҷорӣ ё рамзи эҳтиётӣ хомӯш мекунад."""
    verify_second_factor(db, user, code)
    user.totp_enabled = 0
    user.totp_secret_enc = None
    user.totp_last_step = None
    user.recovery_codes_json = None


def regenerate_recovery(db: Session, user: User, code: str) -> list:
    """Рамзҳои эҳтиётии навро месозад (кӯҳнаҳо беэътибор мешаванд)."""
    verify_second_factor(db, user, code)
    codes = _new_recovery_codes()
    user.recovery_codes_json = json.dumps([_sha256(c) for c in codes])
    return codes


def recovery_left(user: User) -> int:
    """Чанд рамзи эҳтиётӣ боқӣ мондааст."""
    try:
        return len(json.loads(user.recovery_codes_json or "[]"))
    except ValueError:
        return 0


# ---------------------------------------------------------------- санҷиш ва қулф

def check_not_locked(user: User) -> None:
    """Агар ҳисоб пас аз кӯшишҳои нодуруст қулф бошад, OtpError("locked") мебарорад."""
    until = _naive(user.otp_locked_until)
    if until and until > _now():
        raise OtpError("locked", int((until - _now()).total_seconds()) + 1)


def register_failure(db: Session, user: User) -> bool:
    """Кӯшиши нодурустро ҳисоб мекунад; пас аз OTP_MAX_ATTEMPTS ҳисобро қулф мекунад.

    True бармегардонад, агар маҳз ҳамин кӯшиш ҳисобро қулф карда бошад.
    """
    user.otp_failed = (user.otp_failed or 0) + 1
    locked = user.otp_failed >= settings.OTP_MAX_ATTEMPTS
    if locked:
        user.otp_locked_until = _now() + timedelta(minutes=settings.OTP_LOCK_MINUTES)
        user.otp_failed = 0
    db.commit()
    return locked


def _invalid(db: Session, user: User) -> OtpError:
    """Хатои «рамз нодуруст» ё, агар ин кӯшиш қулф кард, «қулф шуд»."""
    if register_failure(db, user):
        return OtpError("locked", settings.OTP_LOCK_MINUTES * 60)
    return OtpError("invalid")


def reset_failures(user: User) -> None:
    """Пас аз рамзи дуруст ҳисобкунаки хатоҳо ва қулфро пок мекунад."""
    user.otp_failed = 0
    user.otp_locked_until = None


def verify_second_factor(db: Session, user: User, code: str) -> str:
    """Рамзи Authenticator ё рамзи эҳтиётиро месанҷад. Натиҷа: «totp» ё «recovery»."""
    check_not_locked(user)
    secret = _decrypt(user.totp_secret_enc or "")
    if not user.totp_enabled or not secret:
        raise OtpError("not_enabled")
    step = match_totp(secret, code, user.totp_last_step)
    if step is not None:
        user.totp_last_step = step
        reset_failures(user)
        return "totp"
    hashes = json.loads(user.recovery_codes_json or "[]")
    wanted = _sha256(_normalize_recovery(code))
    for h in hashes:
        if hmac.compare_digest(h, wanted):
            hashes.remove(h)  # рамзи эҳтиётӣ танҳо як бор кор мекунад
            user.recovery_codes_json = json.dumps(hashes)
            reset_failures(user)
            return "recovery"
    raise _invalid(db, user)


# ---------------------------------------------------------------- чиптаҳо (қадами дуюми воридшавӣ)

def needs_second_factor(user: User) -> bool:
    """Оё ин корбар баъди парол ё рамзи почта бояд рамзи Authenticator ворид кунад."""
    return bool(user.totp_enabled and user.totp_secret_enc)


def issue_ticket(user: User) -> str:
    """Чиптаи кӯтоҳмуддат: «қадами аввал гузашт, акнун рамз лозим». Худи сессия ҳоло дода намешавад."""
    ticket = secrets.token_urlsafe(32)
    with _TICKETS_LOCK:
        _prune_tickets()
        _TICKETS[_sha256(ticket)] = {
            "user_id": user.id,
            "expires": time.time() + settings.OTP_TICKET_SECONDS,
            "attempts": 0,
        }
    return ticket


def _prune_tickets() -> None:
    """Чиптаҳои кӯҳнаро нест мекунад."""
    now = time.time()
    for key in [k for k, v in _TICKETS.items() if v["expires"] < now]:
        _TICKETS.pop(key, None)


def redeem_ticket(db: Session, ticket: str, code: str) -> User:
    """Чипта ва рамзро месанҷад; агар дуруст бошад, корбарро бармегардонад ва чиптаро нест мекунад.

    Ҳар чипта ҳадди аксар OTP_MAX_ATTEMPTS кӯшиш дорад; хатоҳо инчунин ба ҳисоби корбар
    илова мешаванд, то бо чиптаҳои нав қулфро гузаштан ғайриимкон бошад.
    """
    key = _sha256(ticket or "")
    with _TICKETS_LOCK:
        _prune_tickets()
        record = _TICKETS.get(key)
    if record is None:
        raise OtpError("expired")
    user = db.get(User, record["user_id"])
    if user is None:
        raise OtpError("expired")
    try:
        verify_second_factor(db, user, code)
    except OtpError as error:
        with _TICKETS_LOCK:
            record["attempts"] += 1
            if record["attempts"] >= settings.OTP_MAX_ATTEMPTS or error.code == "locked":
                _TICKETS.pop(key, None)
        raise
    with _TICKETS_LOCK:
        _TICKETS.pop(key, None)
    db.commit()
    return user


# ---------------------------------------------------------------- рамз ба почта

def _email_code() -> str:
    """Рамзи тасодуфии 6-рақама барои почта."""
    return str(secrets.randbelow(10 ** DIGITS)).zfill(DIGITS)


def request_email_code(db: Session, email: str, ip: str, purpose: str = "login", sender=None) -> None:
    """Рамзи навро ба почта мефиристад, бо маҳдудиятҳо.

    - на зиёда аз EMAIL_CODE_PER_HOUR рамз ба як почта дар як соат;
    - байни ду рамз на камтар аз EMAIL_CODE_COOLDOWN_SECONDS;
    - рамзҳои пешинаи ҳамин почта беэътибор мешаванд.
    Агар ҳисоб вуҷуд надошта бошад, ҳеҷ чиз фиристода намешавад, вале хато ҳам дода намешавад
    (то касе натавонад бифаҳмад, ки кадом почта сабт шудааст).
    """
    if not email_available():
        raise OtpError("unavailable")
    email = (email or "").strip().lower()
    now = _now()
    hour_ago = now - timedelta(hours=1)
    recent = db.query(EmailCode).filter(
        EmailCode.email == email,
        EmailCode.purpose == purpose,
        EmailCode.created_at >= hour_ago,
    ).order_by(EmailCode.created_at.desc()).all()
    if recent:
        last = _naive(recent[0].created_at)
        wait = settings.EMAIL_CODE_COOLDOWN_SECONDS - int((now - last).total_seconds())
        if wait > 0:
            raise OtpError("cooldown", wait)
    if len(recent) >= settings.EMAIL_CODE_PER_HOUR:
        oldest = _naive(recent[-1].created_at)
        raise OtpError("too_many", int((oldest + timedelta(hours=1) - now).total_seconds()) + 1)
    user = db.query(User).filter(User.email == email).first()
    # Рамзи кӯҳнаро беэътибор мекунем ва сабти навро ҳамеша месозем (барои ҳисоби маҳдудият).
    db.query(EmailCode).filter(EmailCode.email == email, EmailCode.purpose == purpose,
                               EmailCode.used == 0).update({EmailCode.used: 1})
    code = _email_code()
    db.add(EmailCode(
        email=email, purpose=purpose, code_hash=_sha256(f"{email}:{code}"),
        expires_at=now + timedelta(seconds=settings.EMAIL_CODE_TTL_SECONDS),
        ip=(ip or "")[:64], used=0 if user else 1,
    ))
    db.commit()
    if user is not None:
        (sender or send_email)(email, code)


def verify_email_code(db: Session, email: str, code: str, purpose: str = "login") -> User:
    """Рамзи почтаро месанҷад: мӯҳлат, 5 кӯшиш, якдафъаина. Корбарро бармегардонад."""
    email = (email or "").strip().lower()
    code = (code or "").strip()
    row = db.query(EmailCode).filter(
        EmailCode.email == email, EmailCode.purpose == purpose, EmailCode.used == 0,
    ).order_by(EmailCode.id.desc()).first()
    if row is None or _naive(row.expires_at) < _now():
        raise OtpError("expired")
    if row.attempts >= settings.OTP_MAX_ATTEMPTS:
        row.used = 1
        db.commit()
        raise OtpError("expired")
    if not (len(code) == DIGITS and code.isdigit() and hmac.compare_digest(row.code_hash, _sha256(f"{email}:{code}"))):
        row.attempts += 1
        if row.attempts >= settings.OTP_MAX_ATTEMPTS:
            row.used = 1
        db.commit()
        raise OtpError("invalid")
    row.used = 1
    user = db.query(User).filter(User.email == email).first()
    db.commit()
    if user is None:
        raise OtpError("expired")
    return user


def send_email(to: str, code: str) -> None:
    """Рамзро бо SMTP мефиристад (се забон дар як мактуб, то забони корбар маълум набошад ҳам)."""
    minutes = settings.EMAIL_CODE_TTL_SECONDS // 60
    msg = EmailMessage()
    msg["Subject"] = f"{code} — NIGOH Family"
    msg["From"] = settings.SMTP_FROM
    msg["To"] = to
    msg.set_content(
        f"Рамзи воридшавӣ: {code}\nОн {minutes} дақиқа эътибор дорад. Агар шумо дархост накарда бошед, ин мактубро нодида гиред.\n\n"
        f"Код для входа: {code}\nОн действует {minutes} минут. Если вы не запрашивали код, просто проигнорируйте письмо.\n\n"
        f"Your sign-in code: {code}\nIt is valid for {minutes} minutes. If you did not ask for it, ignore this email.\n\n"
        "NIGOH Family · https://nigohfamily.qobus.tj"
    )
    if settings.SMTP_SSL:
        server = smtplib.SMTP_SSL(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15)
    else:
        server = smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15)
        server.starttls()
    with server:
        if settings.SMTP_USER:
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
        server.send_message(msg)


# ---------------------------------------------------------------- матни хатоҳо

# Калиди хато → (тоҷикӣ, русӣ, англисӣ).
MESSAGES = {
    "invalid": ("Рамз нодуруст аст", "Неверный код", "Wrong code"),
    "expired": ("Мӯҳлати рамз гузашт. Аз нав ворид шавед", "Срок действия кода истёк. Войдите снова", "The code has expired. Please sign in again"),
    "locked": ("Кӯшишҳои зиёди нодуруст. Ҳисоб муваққатан қулф шуд", "Слишком много неверных попыток. Аккаунт временно заблокирован", "Too many wrong attempts. The account is temporarily locked"),
    "cooldown": ("Рамз нав фиристода шуд. Каме интизор шавед", "Код только что отправлен. Подождите немного", "A code was just sent. Please wait a little"),
    "too_many": ("Рамзҳои зиёд дархост шуданд. Баъдтар кӯшиш кунед", "Запрошено слишком много кодов. Попробуйте позже", "Too many codes requested. Please try later"),
    "unavailable": ("Ин навъи ҳимоя дар сервер танзим нашудааст", "Этот способ защиты не настроен на сервере", "This protection is not set up on the server"),
    "already_enabled": ("Ҳимояи дуқабата аллакай фаъол аст", "Двухфакторная защита уже включена", "Two-step verification is already on"),
    "no_setup": ("Аввал танзимро сар кунед", "Сначала начните настройку", "Start the setup first"),
    "not_enabled": ("Ҳимояи дуқабата фаъол нест", "Двухфакторная защита не включена", "Two-step verification is not on"),
}
_UNITS = {"tg": ("с", "дақ"), "ru": ("с", "мин"), "en": ("s", "min")}


def message(error: OtpError, lang: str = "tg") -> str:
    """Матни хато бо забони корбар ва вақти боқимонда (масалан «… (14 дақ)»)."""
    idx = {"tg": 0, "ru": 1, "en": 2}.get(lang, 0)
    text = MESSAGES.get(error.code, MESSAGES["invalid"])[idx]
    sec, minute = _UNITS.get(lang, _UNITS["tg"])
    if error.retry_after and error.code == "cooldown":
        return f"{text} ({error.retry_after} {sec})"
    if error.retry_after and error.code in ("locked", "too_many"):
        return f"{text} ({max(1, (error.retry_after + 59) // 60)} {minute})"
    return text
