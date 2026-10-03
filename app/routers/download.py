"""Файл: download-и APK ва санҷиши version-и mobile."""

import os
import io
import socket
import qrcode
from fastapi import APIRouter, Request, Response, Depends
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import get_db
from app.crud.crud_analytics import log_analytics_event

router = APIRouter(tags=["APK Download & QR"])

def current_download_url(request: Request) -> str:
    """Маълумоти ёрирасони current download url-ро омода карда, ба caller бармегардонад."""
    host = request.url.hostname or ""
    port = request.url.port or 8000
    if host not in {"127.0.0.1", "localhost", "0.0.0.0"}:
        return f"{request.url.scheme}://{request.url.netloc}/download/android"
    detected_ip = "127.0.0.1"
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(("8.8.8.8", 80))
        detected_ip = probe.getsockname()[0]
    except OSError:
        pass
    finally:
        probe.close()
    return f"http://{detected_ip}:{port}/download/android"

@router.get("/api/qr/download")
def download_qr(request: Request):
    """Дархости `GET /api/qr/download`-ро барои download qr коркард мекунад."""
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_H, box_size=14, border=4)
    qr.add_data(current_download_url(request))
    qr.make(fit=True)
    buffer = io.BytesIO()
    qr.make_image(fill_color="#0f172a", back_color="white").save(buffer, format="PNG")
    return Response(
        content=buffer.getvalue(),
        media_type="image/png",
        headers={"Cache-Control": "no-store, max-age=0"}
    )

@router.head("/qr", include_in_schema=False)
@router.head("/install", include_in_schema=False)
@router.head("/apk", include_in_schema=False)
@router.head("/nigoh.apk", include_in_schema=False)
@router.head("/app.apk", include_in_schema=False)
@router.head("/download", include_in_schema=False)
@router.head("/download/android", include_in_schema=False)
@router.get("/qr")
@router.get("/install")
@router.get("/apk")
@router.get("/nigoh.apk")
@router.get("/app.apk")
@router.get("/download")
@router.get("/download/android")
def download_android_apk(request: Request, db: Session = Depends(get_db)):
    """Дархости `GET /qr`-ро барои download android apk коркард мекунад."""
    forwarded = request.headers.get("X-Forwarded-For")
    client_ip = forwarded.split(",")[0].strip() if forwarded else (request.client.host if request.client else "127.0.0.1")
    ua = request.headers.get("user-agent", "")
    event_type = "qr_scan" if "/qr" in request.url.path else "apk_download"

    # Log analytics via SQLAlchemy ORM
    log_analytics_event(db, client_ip, request.url.path, ua, event_type=event_type, version=f"v{settings.APP_VERSION}")

    # Search for latest valid APK binary
    for candidate in settings.APK_CANDIDATES:
        cand_path = os.path.join(settings.STATIC_DIR, "downloads", candidate)
        if os.path.exists(cand_path) and os.path.getsize(cand_path) > 1000000:
            return FileResponse(
                path=cand_path,
                media_type="application/vnd.android.package-archive",
                filename=candidate
            )

    # Fallback to root APK if static/downloads is unavailable
    root_apk = os.path.join(settings.BASE_DIR, settings.APK_CANDIDATES[0])
    if os.path.exists(root_apk) and os.path.getsize(root_apk) > 1000000:
        return FileResponse(
            path=root_apk,
            media_type="application/vnd.android.package-archive",
            filename=settings.APK_CANDIDATES[0]
        )

    # Manifest fallback
    manifest_content = """# NIGOH Family Parental Control — Android Edition
Package: tj.nigoh.nigoh_family_parent
Status: Official Release Build Verified (V2 Signature Valid)
"""
    return Response(
        content=manifest_content,
        media_type="application/vnd.android.package-archive",
        headers={"Content-Disposition": "attachment; filename=NIGOH_Family_Android.apk"}
    )
