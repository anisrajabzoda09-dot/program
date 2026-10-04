"""Файл: роутҳои ҳимояи дуқабата — қадами рамз пас аз парол, рамз ба почта ва танзими
Authenticator барои сайт (cookie) ва барномаи Android (Bearer token).

Маҳдудиятҳо дар app/core/otp.py: 5 кӯшиш → қулфи 15 дақиқа, чиптаи 5-дақиқаӣ, рамзи почта
10 дақиқа, 3 рамз дар як соат ва 60 сония байни рамзҳо. Ҳар роут инчунин аз рӯи IP маҳдуд аст.
"""

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core import otp
from app.core.config import settings
from app.core.i18n import request_lang
from app.core.mobile_auth import require_mobile_user
from app.core.security import SESSIONS, check_rate_limit, get_current_user
from app.db.session import get_db
from app.models.user import User

router = APIRouter(tags=["Two-step verification"])
templates = Jinja2Templates(directory=settings.TEMPLATES_DIR)


class TicketCode(BaseModel):
    """Чипта аз қадами аввал ва рамзи 6-рақама (ё рамзи эҳтиётӣ)."""

    ticket: str = Field(..., min_length=20, max_length=200)
    code: str = Field(..., min_length=6, max_length=12)


class EmailOnly(BaseModel):
    """Почта барои фиристодани рамз."""

    email: str = Field(..., min_length=3, max_length=254)


class EmailCodeIn(BaseModel):
    """Почта ва рамзи 6-рақама аз мактуб."""

    email: str = Field(..., min_length=3, max_length=254)
    code: str = Field(..., min_length=6, max_length=6)


class CodeOnly(BaseModel):
    """Як рамз барои тасдиқ, хомӯш кардан ё рамзҳои эҳтиётӣ."""

    code: str = Field(..., min_length=6, max_length=12)


def _lang(request: Request) -> str:
    """Забони ҷавоб: header-и X-NIGOH-Lang ё ?lang= ё тоҷикӣ."""
    lang = request.query_params.get("lang")
    return lang if lang in ("tg", "ru", "en") else request_lang(request.headers)


def _fail(request: Request, error: otp.OtpError) -> HTTPException:
    """OtpError-ро ба ҷавоби HTTP бо матни забони корбар табдил медиҳад."""
    status = {"locked": 429, "cooldown": 429, "too_many": 429, "unavailable": 503,
              "expired": 401}.get(error.code, 400)
    headers = {"Retry-After": str(error.retry_after)} if error.retry_after else None
    return HTTPException(status_code=status, detail=otp.message(error, _lang(request)), headers=headers)


def _client_ip(request: Request) -> str:
    """IP-и корбар бо назардошти nginx."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else ""


# ------------------------------------------------------------------ танзимот (оммавӣ)

@router.get("/api/auth/otp/config")
@router.get("/api/mobile/v3/auth/otp/config")
def otp_config():
    """Кадом навъҳои OTP дар сервер фаъоланд (барои нишон додан ё пинҳон кардани тугмаҳо)."""
    return {"totp": otp.totp_available(), "email": otp.email_available()}


# ------------------------------------------------------------------ сайт: воридшавӣ

def _web_session(request: Request, user: User, db: Session) -> JSONResponse:
    """Сессияи сайтро бо cookie месозад (ҳамон тавре ки воридшавии оддӣ)."""
    from app.routers.auth import _set_session_cookie
    redirect = "/admin" if user.role == "admin" else "/get"
    response = JSONResponse({"status": "success", "user": user.to_dict(), "redirect": redirect})
    _set_session_cookie(response, request, user.to_dict())
    return response


@router.post("/api/auth/login/otp")
def web_login_otp(payload: TicketCode, request: Request, db: Session = Depends(get_db)):
    """Қадами дуюми воридшавии сайт: рамзи Authenticator ё рамзи эҳтиётӣ."""
    check_rate_limit(request, "otp_web", max_requests=20, window_seconds=300)
    try:
        user = otp.redeem_ticket(db, payload.ticket, payload.code)
    except otp.OtpError as error:
        raise _fail(request, error)
    return _web_session(request, user, db)


@router.post("/api/auth/email-code")
@router.post("/api/mobile/v3/auth/email-code")
def email_code_request(payload: EmailOnly, request: Request, db: Session = Depends(get_db)):
    """Рамзи воридшавиро ба почта мефиристад. Ҷавоб ҳамеша якхела аст (почтаҳо ошкор намешаванд)."""
    check_rate_limit(request, "email_code", max_requests=10, window_seconds=3600)
    try:
        otp.request_email_code(db, payload.email, _client_ip(request))
    except otp.OtpError as error:
        raise _fail(request, error)
    return {"status": "sent", "expires_in": settings.EMAIL_CODE_TTL_SECONDS}


@router.post("/api/auth/email-code/verify")
def web_email_code_verify(payload: EmailCodeIn, request: Request, db: Session = Depends(get_db)):
    """Рамзи почтаро месанҷад; агар Authenticator фаъол бошад, қадами дуюмро талаб мекунад."""
    check_rate_limit(request, "email_verify", max_requests=20, window_seconds=600)
    try:
        user = otp.verify_email_code(db, payload.email, payload.code)
        otp.check_not_locked(user)
    except otp.OtpError as error:
        raise _fail(request, error)
    if otp.needs_second_factor(user):
        return {"status": "otp_required", "ticket": otp.issue_ticket(user)}
    return _web_session(request, user, db)


# ------------------------------------------------------------------ барнома: воридшавӣ

@router.post("/api/mobile/v3/auth/login/otp")
def mobile_login_otp(payload: TicketCode, request: Request, db: Session = Depends(get_db)):
    """Қадами дуюми воридшавии барнома; token-и барномаро медиҳад."""
    check_rate_limit(request, "otp_mobile", max_requests=20, window_seconds=300)
    try:
        user = otp.redeem_ticket(db, payload.ticket, payload.code)
    except otp.OtpError as error:
        raise _fail(request, error)
    from app.routers.mobile_auth import _auth_response
    return _auth_response(db, user, request)


@router.post("/api/mobile/v3/auth/email-code/verify")
def mobile_email_code_verify(payload: EmailCodeIn, request: Request, db: Session = Depends(get_db)):
    """Рамзи почтаро дар барнома месанҷад; бо Authenticator — қадами дуюм."""
    check_rate_limit(request, "email_verify", max_requests=20, window_seconds=600)
    try:
        user = otp.verify_email_code(db, payload.email, payload.code)
        otp.check_not_locked(user)
    except otp.OtpError as error:
        raise _fail(request, error)
    if user.role == "admin":
        raise HTTPException(status_code=403, detail="Ҳисоби админ барои барнома нест")
    if otp.needs_second_factor(user):
        return {"status": "otp_required", "ticket": otp.issue_ticket(user)}
    from app.routers.mobile_auth import _auth_response
    return _auth_response(db, user, request)


# ------------------------------------------------------------------ танзими Authenticator

def _status(user: User) -> dict:
    """Ҳолати ҳимояи дуқабата барои экран."""
    return {
        "available": otp.totp_available(),
        "enabled": bool(user.totp_enabled),
        "recovery_left": otp.recovery_left(user) if user.totp_enabled else 0,
    }


def _setup(db: Session, user: User, request: Request) -> dict:
    """Калиди навро месозад ва QR-ро бармегардонад."""
    check_rate_limit(request, "totp_setup", max_requests=10, window_seconds=600)
    try:
        data = otp.begin_setup(user)
    except otp.OtpError as error:
        raise _fail(request, error)
    db.commit()
    return {"status": "pending", **data}


def _confirm(db: Session, user: User, request: Request, code: str) -> dict:
    """Аввалин рамзро месанҷад ва рамзҳои эҳтиётиро бармегардонад."""
    check_rate_limit(request, "totp_confirm", max_requests=20, window_seconds=600)
    try:
        codes = otp.confirm_setup(db, user, code)
    except otp.OtpError as error:
        raise _fail(request, error)
    db.commit()
    return {"status": "enabled", "recovery_codes": codes, **_status(user)}


def _disable(db: Session, user: User, request: Request, code: str) -> dict:
    """Ҳимояи дуқабатаро бо рамз хомӯш мекунад."""
    check_rate_limit(request, "totp_disable", max_requests=20, window_seconds=600)
    try:
        otp.disable(db, user, code)
    except otp.OtpError as error:
        raise _fail(request, error)
    db.commit()
    return {"status": "disabled", **_status(user)}


def _recovery(db: Session, user: User, request: Request, code: str) -> dict:
    """Рамзҳои эҳтиётии навро медиҳад."""
    check_rate_limit(request, "totp_recovery", max_requests=10, window_seconds=600)
    try:
        codes = otp.regenerate_recovery(db, user, code)
    except otp.OtpError as error:
        raise _fail(request, error)
    db.commit()
    return {"status": "enabled", "recovery_codes": codes, **_status(user)}


def _web_user(request: Request, db: Session) -> User:
    """Корбари воридшудаи сайтро аз база мегирад; бе сессия — 401."""
    session = get_current_user(request)
    user = db.get(User, session.get("id")) if session else None
    if user is None:
        raise HTTPException(status_code=401, detail="Ворид шавед")
    return user


def _mobile_db_user(request: Request, db: Session) -> User:
    """Корбари барномаро аз token мегирад."""
    info = require_mobile_user(request, db)
    user = db.get(User, info["id"])
    if user is None:
        raise HTTPException(status_code=401, detail="Лутфан аз нав ворид шавед")
    return user


def _account_page(lang: str):
    """Саҳифаи «Ҳимояи ҳисоб»-ро барои забони додашуда месозад."""
    prefix = "" if lang == "tg" else f"/{lang}"

    def view(request: Request, db: Session = Depends(get_db)):
        """Саҳифаи «Ҳимояи ҳисоб» дар сайт: фаъол ё хомӯш кардани Authenticator."""
        session = get_current_user(request)
        user = db.get(User, session.get("id")) if session else None
        if user is None:
            return RedirectResponse("/auth" + (f"?lang={lang}" if lang != "tg" else ""), status_code=303)
        return templates.TemplateResponse(
            request=request, name="account_security.html",
            context={"user": user.to_dict(), "status": _status(user), "lang": lang, "lang_prefix": prefix,
                     "page_path": f"{prefix}/account/security", "base_path": "/account/security",
                     "active": "account", "email_available": otp.email_available(),
                     "app_version": settings.APP_VERSION},
        )

    router.add_api_route(f"{prefix}/account/security", view, methods=["GET"], response_class=HTMLResponse,
                         include_in_schema=False)


for _page_lang in ("tg", "ru", "en"):
    _account_page(_page_lang)


@router.get("/api/account/totp")
def web_totp_status(request: Request, db: Session = Depends(get_db)):
    """Ҳолати Authenticator барои корбари сайт."""
    return _status(_web_user(request, db))


@router.post("/api/account/totp/setup")
def web_totp_setup(request: Request, db: Session = Depends(get_db)):
    """Оғози танзими Authenticator дар сайт."""
    return _setup(db, _web_user(request, db), request)


@router.post("/api/account/totp/confirm")
def web_totp_confirm(payload: CodeOnly, request: Request, db: Session = Depends(get_db)):
    """Тасдиқи Authenticator дар сайт."""
    return _confirm(db, _web_user(request, db), request, payload.code)


@router.post("/api/account/totp/disable")
def web_totp_disable(payload: CodeOnly, request: Request, db: Session = Depends(get_db)):
    """Хомӯш кардани Authenticator дар сайт; сессияҳои дигари сайти ин корбар баста мешаванд."""
    user = _web_user(request, db)
    result = _disable(db, user, request, payload.code)
    _close_other_web_sessions(request, user.id)
    return result


@router.post("/api/account/totp/recovery")
def web_totp_recovery(payload: CodeOnly, request: Request, db: Session = Depends(get_db)):
    """Рамзҳои эҳтиётии нав дар сайт."""
    return _recovery(db, _web_user(request, db), request, payload.code)


@router.get("/api/mobile/v3/me/totp")
def mobile_totp_status(request: Request, db: Session = Depends(get_db)):
    """Ҳолати Authenticator барои корбари барнома."""
    return _status(_mobile_db_user(request, db))


@router.post("/api/mobile/v3/me/totp/setup")
def mobile_totp_setup(request: Request, db: Session = Depends(get_db)):
    """Оғози танзими Authenticator дар барнома."""
    return _setup(db, _mobile_db_user(request, db), request)


@router.post("/api/mobile/v3/me/totp/confirm")
def mobile_totp_confirm(payload: CodeOnly, request: Request, db: Session = Depends(get_db)):
    """Тасдиқи Authenticator дар барнома."""
    return _confirm(db, _mobile_db_user(request, db), request, payload.code)


@router.post("/api/mobile/v3/me/totp/disable")
def mobile_totp_disable(payload: CodeOnly, request: Request, db: Session = Depends(get_db)):
    """Хомӯш кардани Authenticator дар барнома."""
    return _disable(db, _mobile_db_user(request, db), request, payload.code)


@router.post("/api/mobile/v3/me/totp/recovery")
def mobile_totp_recovery(payload: CodeOnly, request: Request, db: Session = Depends(get_db)):
    """Рамзҳои эҳтиётии нав дар барнома."""
    return _recovery(db, _mobile_db_user(request, db), request, payload.code)


def _close_other_web_sessions(request: Request, user_id: int) -> None:
    """Ҳамаи сессияҳои сайти ин корбарро, ба ғайр аз ҳозира, мебандад."""
    current = request.cookies.get(settings.SESSION_COOKIE_NAME)
    for token, data in list(SESSIONS.items()):
        if token != current and data.get("id") == user_id:
            SESSIONS.pop(token, None)
