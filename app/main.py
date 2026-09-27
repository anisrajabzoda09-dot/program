import os
from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.db.session import SessionLocal
from app.db.init_db import init_db
from app.crud.crud_analytics import log_analytics_event

# Modular Routers (DRF-style Separation of Concerns)
from app.routers.public import router as public_router
from app.routers.auth import router as auth_router
from app.routers.admin import router as admin_router
from app.routers.mobile import router as mobile_router
from app.routers.download import router as download_router

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
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 2. Advanced Security Headers & Analytics Tracking Middleware
@app.middleware("http")
async def security_and_analytics_middleware(request: Request, call_next):
    # Extract client IP supporting Nginx reverse proxy
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        client_ip = forwarded.split(",")[0].strip()
    elif request.client:
        client_ip = request.client.host
    else:
        client_ip = "127.0.0.1"

    path = request.url.path
    if path in ["/", "/auth", "/admin"]:
        user_agent = request.headers.get("user-agent", "")
        # Track analytics using scoped SQLAlchemy session
        db = SessionLocal()
        try:
            log_analytics_event(db, client_ip, path, user_agent, event_type="page_view", version=settings.APP_VERSION)
        finally:
            db.close()

    response = await call_next(request)

    # Security Headers against Web Attacks (XSS, Clickjacking, MIME sniffing)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"

    return response

# 3. Mount Static Assets
app.mount("/static", StaticFiles(directory=settings.STATIC_DIR), name="static")

# 4. Startup Database Initialization
@app.on_event("startup")
def on_startup():
    init_db()

# 5. Include Modular Routers
app.include_router(public_router)
app.include_router(auth_router)
app.include_router(admin_router)
app.include_router(mobile_router)
app.include_router(download_router)
