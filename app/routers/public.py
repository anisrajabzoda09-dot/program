import os
from fastapi import APIRouter, Request, Response, Depends
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.core.config import settings
from app.core.security import get_current_user
from app.db.session import get_db
from app.models.review import Review

router = APIRouter(tags=["Public & SEO"])
templates = Jinja2Templates(directory=settings.TEMPLATES_DIR)

@router.get("/robots.txt", response_class=Response)
def get_robots_txt():
    content = "User-agent: *\nAllow: /\nDisallow: /api/\nSitemap: https://nigohfamily.qobus.tj/sitemap.xml\n"
    return Response(content=content, media_type="text/plain")

@router.get("/sitemap.xml", response_class=Response)
def get_sitemap_xml():
    xml = """<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://nigohfamily.qobus.tj/</loc>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://nigohfamily.qobus.tj/auth</loc>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>https://nigohfamily.qobus.tj/qr</loc>
    <priority>0.9</priority>
  </url>
  <url>
    <loc>https://nigohfamily.qobus.tj/download/android</loc>
    <priority>0.9</priority>
  </url>
</urlset>"""
    return Response(content=xml, media_type="application/xml")

@router.get("/health")
def health_check(db: Session = Depends(get_db)):
    """System health check and diagnostic monitoring endpoint"""
    db_ok = False
    try:
        db.execute(text("SELECT 1"))
        db_ok = True
    except Exception:
        db_ok = False

    apk_exists = False
    apk_size = 0
    active_apk_name = settings.APK_CANDIDATES[0]
    for candidate in settings.APK_CANDIDATES:
        cand_path = os.path.join(settings.STATIC_DIR, "downloads", candidate)
        if os.path.exists(cand_path) and os.path.getsize(cand_path) > 1000000:
            apk_exists = True
            apk_size = os.path.getsize(cand_path)
            active_apk_name = candidate
            break

    return {
        "status": "healthy" if (db_ok and apk_exists) else "degraded",
        "domain": settings.OFFICIAL_DOMAIN,
        "version": settings.APP_VERSION,
        "version_code": settings.APP_VERSION_CODE,
        "database_connected": db_ok,
        "apk_available": apk_exists,
        "apk_bytes": apk_size,
        "active_apk": active_apk_name
    }

@router.get("/", response_class=HTMLResponse)
def landing_page(request: Request, db: Session = Depends(get_db)):
    user = get_current_user(request)
    reviews = [r.to_dict() for r in db.query(Review).order_by(Review.id.desc()).all()]
    return templates.TemplateResponse(
        request=request,
        name="landing.html",
        context={"user": user, "reviews": reviews}
    )

@router.get("/3d", response_class=HTMLResponse)
@router.get("/nigoh3d", response_class=HTMLResponse)
def nigoh_3d_presentation(request: Request):
    return templates.TemplateResponse(request=request, name="nigoh3d.html", context={})

@router.get("/weevolve", response_class=HTMLResponse)
@router.get("/evolve", response_class=HTMLResponse)
def weevolve_showcase_page(request: Request):
    return templates.TemplateResponse(request=request, name="weevolve.html", context={})
