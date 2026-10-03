"""Файл: содир кардани ҷузъҳои ин package барои истифода дар бахшҳои дигар."""

from app.routers.public import router as public_router
from app.routers.auth import router as auth_router
from app.routers.admin import router as admin_router
from app.routers.mobile import router as mobile_router
from app.routers.download import router as download_router

__all__ = [
    "public_router",
    "auth_router",
    "admin_router",
    "mobile_router",
    "download_router"
]
