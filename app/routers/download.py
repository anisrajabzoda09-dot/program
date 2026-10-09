"""Файл: download-и APK ва санҷиши version-и mobile."""

import os
import io
import re
import socket
from zipfile import BadZipFile, ZipFile
import qrcode
from fastapi import APIRouter, Request, Response, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import get_db
from app.crud.crud_analytics import log_analytics_event

router = APIRouter(tags=["APK Download & QR"])


def get_android_release() -> dict:
    release = {
        "available": False,
        "path": None,
        "filename": None,
        "version": settings.APP_VERSION,
        "version_code": settings.APP_VERSION_CODE,
        "bytes": 0,
        "size_label": None,
    }
    candidates = [
        (os.path.join(settings.STATIC_DIR, "downloads", candidate), candidate)
        for candidate in settings.APK_CANDIDATES
    ]
    if settings.APK_CANDIDATES:
        candidates.append((os.path.join(settings.BASE_DIR, settings.APK_CANDIDATES[0]), settings.APK_CANDIDATES[0]))
    for path, filename in candidates:
        try:
            size = os.path.getsize(path)
            if size <= 1_000_000:
                continue
            with ZipFile(path) as archive:
                archive.getinfo("AndroidManifest.xml")
                archive.getinfo("classes.dex")
        except (OSError, BadZipFile, KeyError):
            continue
        version_match = re.search(r"_v(\d+(?:\.\d+)+)\.apk$", filename)
        version = version_match.group(1) if version_match else None
        return dict(
            release, available=True, path=path, filename=filename, bytes=size,
            size_label=f"{size / 1_048_576:.1f} MB", version=version,
            version_code=settings.APP_VERSION_CODE if version == settings.APP_VERSION else None,
        )
    return release


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
    qr.add_data(current_download_url(request).rsplit("/download/android", 1)[0] + "/qr")
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
    release = get_android_release()
    if not release["available"]:
        raise HTTPException(
            status_code=503,
            detail="Файли насби Android ҳоло дастнорас аст. Баъдтар кӯшиш кунед.",
            headers={"Retry-After": "300", "Cache-Control": "no-store"},
        )
    if request.method == "GET":
        forwarded = request.headers.get("X-Forwarded-For")
        client_ip = forwarded.split(",")[0].strip() if forwarded else (request.client.host if request.client else "127.0.0.1")
        event_type = "qr_scan" if request.url.path == "/qr" else "apk_download"
        log_analytics_event(
            db, client_ip, request.url.path, request.headers.get("user-agent", ""),
            event_type=event_type, version=f"v{release['version']}" if release["version"] else "unknown",
        )
    return FileResponse(
        path=release["path"],
        media_type="application/vnd.android.package-archive",
        filename=release["filename"],
        headers={"Cache-Control": "no-store"},
    )
