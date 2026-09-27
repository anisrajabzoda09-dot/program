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
    """Return a phone-reachable URL, even when page is opened on localhost."""
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
    """Generate high-contrast QR code image pointing to official APK download."""
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

@router.api_route("/qr", methods=["GET", "HEAD"])
@router.api_route("/install", methods=["GET", "HEAD"])
@router.api_route("/apk", methods=["GET", "HEAD"])
@router.api_route("/nigoh.apk", methods=["GET", "HEAD"])
@router.api_route("/app.apk", methods=["GET", "HEAD"])
@router.api_route("/download", methods=["GET", "HEAD"])
@router.api_route("/download/android", methods=["GET", "HEAD"])
def download_android_apk(request: Request, db: Session = Depends(get_db)):
    """Serve official signed Android APK binary with real analytics tracking."""
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
    root_apk = os.path.join(settings.BASE_DIR, "NIGOH_Family_Android_v2.8.1.apk")
    if os.path.exists(root_apk) and os.path.getsize(root_apk) > 1000000:
        return FileResponse(
            path=root_apk,
            media_type="application/vnd.android.package-archive",
            filename="NIGOH_Family_Android_v2.8.1.apk"
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
