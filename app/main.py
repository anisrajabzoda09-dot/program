"""Файл: ҷамъ кардани FastAPI app, middleware, startup ва ҳамаи router-ҳо."""

import os
import time
from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from starlette.background import BackgroundTask

from app.core.config import settings
from app.db.session import SessionLocal
from app.db.init_db import init_db
from app.crud.crud_analytics import log_analytics_event
from app.crud.crud_privacy import anonymize_site_analytics

# Modular Routers (DRF-style Separation of Concerns)
from app.routers.public import router as public_router
from app.routers.auth import router as auth_router
from app.routers.admin import router as admin_router
from app.routers.mobile import router as mobile_router
from app.routers.mobile_auth import router as mobile_auth_router
from app.routers.mobile_family import router as mobile_family_router
from app.routers.mobile_realtime import router as mobile_realtime_router
from app.routers.download import router as download_router
from app.routers.contact import router as contact_router

app = FastAPI(
    title=settings.PROJECT_NAME,
    description=settings.PROJECT_DESCRIPTION,
    version=settings.APP_VERSION,
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

# 1. CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.OFFICIAL_DOMAIN, "http://localhost:8080", "http://127.0.0.1:8080"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=[
        "Accept",
        "Authorization",
        "Content-Type",
        "X-Requested-With",
        "X-NIGOH-Role",
    ],
)

# Саҳифаҳое, ки боздид аз онҳо дар омори панели админ ҳисоб мешавад.
_TRACKED_PATHS = frozenset(
    prefix + page
    for prefix in ("", "/ru", "/en")
    for page in ("/", "/features", "/how-it-works", "/security", "/faq", "/get")
) | {"/ru", "/en", "/auth", "/admin"}


# Вақти охирини пок кардани IP-ҳои кӯҳна; дар як рӯз як бор кифоя аст.
_last_anonymize = 0.0


def _log_page_view(ip: str, path: str, user_agent: str) -> None:
    """Як боздиди саҳифаро бо сессияи алоҳидаи база сабт мекунад (дар замина)."""
    global _last_anonymize
    db = SessionLocal()
    try:
        log_analytics_event(db, ip, path, user_agent, event_type="page_view", version=settings.APP_VERSION)
        if time.monotonic() - _last_anonymize > 86400 or _last_anonymize == 0.0:
            _last_anonymize = time.monotonic()
            anonymize_site_analytics(db)
            db.commit()
    except Exception:
        db.rollback()
    finally:
        db.close()


def _attach_background(response, task: BackgroundTask) -> None:
    """Вазифаи заминаро ба ҷавоб мепайвандад, бе он ки вазифаи мавҷударо гум кунад."""
    previous = response.background
    if previous is None:
        response.background = task
        return

    async def _both():
        await previous()
        await task()

    response.background = BackgroundTask(_both)


# 2. Advanced Security Headers & Analytics Tracking Middleware
@app.middleware("http")
async def security_and_analytics_middleware(request: Request, call_next):
    """Маълумоти ёрирасони security and омор middleware-ро омода карда, ба caller бармегардонад."""

    # Extract client IP supporting Nginx reverse proxy
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        client_ip = forwarded.split(",")[0].strip()
    elif request.client:
        client_ip = request.client.host
    else:
        client_ip = "127.0.0.1"

    path = request.url.path
    response = await call_next(request)

    # Омор пас аз фиристодани ҷавоб дар thread-и алоҳида навишта мешавад,
    # то навиштан ба база саҳифаро суст накунад ва event loop-ро манъ накунад.
    if path in _TRACKED_PATHS:
        _attach_background(response, BackgroundTask(
            _log_page_view, client_ip, path, request.headers.get("user-agent", ""),
        ))

    # Файлҳои static бо ?v=<версия> тағйир намеёбанд — браузер онҳоро як сол
    # нигоҳ медорад; бе ?v= — як соат (APK-ҳо ҳамеша аз нав санҷида мешаванд).
    if path.startswith("/static/") and not path.startswith("/static/downloads/"):
        if "v=" in request.url.query:
            response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
        else:
            response.headers.setdefault("Cache-Control", "public, max-age=3600")

    # Security Headers against Web Attacks (XSS, Clickjacking, MIME sniffing)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Permissions-Policy"] = "camera=(self), microphone=(), geolocation=(self)"
    response.headers["Cross-Origin-Opener-Policy"] = "same-origin-allow-popups"
    response.headers["Cross-Origin-Resource-Policy"] = "same-site"
    if request.url.scheme == "https":
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

    return response

# 3. Mount Static Assets
app.mount("/static", StaticFiles(directory=settings.STATIC_DIR), name="static")

# 4. Startup Database Initialization
@app.on_event("startup")
async def on_startup():
    """on startup-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    init_db()
    # Phones keep long-poll requests open (notifications, call signaling);
    # each one holds a worker thread, so allow more than the default 40.
    import anyio.to_thread

    anyio.to_thread.current_default_thread_limiter().total_tokens = 200

# Mobile API errors in the phone's language (X-NIGOH-Lang: tg | ru | en)
from fastapi.exceptions import HTTPException as _HTTPException  # noqa: E402
from fastapi.exception_handlers import http_exception_handler as _default_http_handler  # noqa: E402
from app.core.i18n import request_lang, translate  # noqa: E402


@app.exception_handler(_HTTPException)
async def localized_http_exception(request: Request, exc: _HTTPException):
    """Маълумоти ёрирасони localized http exception-ро омода карда, ба caller бармегардонад."""

    if request.url.path.startswith("/api/mobile") and isinstance(exc.detail, str):
        exc = _HTTPException(
            status_code=exc.status_code,
            detail=translate(exc.detail, request_lang(request.headers)),
            headers=exc.headers,
        )
    return await _default_http_handler(request, exc)


# 5. Include Modular Routers
app.include_router(public_router)
app.include_router(auth_router)
app.include_router(admin_router)
app.include_router(mobile_router)
app.include_router(mobile_auth_router)
app.include_router(mobile_family_router)
app.include_router(mobile_realtime_router)
app.include_router(download_router)
app.include_router(contact_router)
