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

@router.head("/robots.txt", include_in_schema=False)
@router.get("/robots.txt", response_class=Response)
def get_robots_txt():
    content = """User-agent: *
Allow: /
Disallow: /admin
Disallow: /api/admin/

User-agent: Googlebot
Allow: /

User-agent: Googlebot-Mobile
Allow: /

User-agent: Googlebot-Image
Allow: /static/

User-agent: Yandex
Allow: /

User-agent: Bingbot
Allow: /

Sitemap: https://nigohfamily.qobus.tj/sitemap.xml
Host: https://nigohfamily.qobus.tj
"""
    return Response(content=content, media_type="text/plain; charset=utf-8")

@router.head("/sitemap.xml", include_in_schema=False)
@router.get("/sitemap.xml", response_class=Response)
def get_sitemap_xml():
    xml = """<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml"
        xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">
  <url>
    <loc>https://nigohfamily.qobus.tj/</loc>
    <lastmod>2026-09-27</lastmod>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
    <image:image>
      <image:loc>https://nigohfamily.qobus.tj/static/images/nigoh_family_icon.png</image:loc>
      <image:title>NIGOH Family Parental Control</image:title>
    </image:image>
  </url>
  <url>
    <loc>https://nigohfamily.qobus.tj/download/android</loc>
    <lastmod>2026-09-27</lastmod>
    <changefreq>daily</changefreq>
    <priority>0.95</priority>
  </url>
  <url>
    <loc>https://nigohfamily.qobus.tj/qr</loc>
    <lastmod>2026-09-27</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.9</priority>
  </url>
  <url>
    <loc>https://nigohfamily.qobus.tj/auth</loc>
    <lastmod>2026-09-27</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>https://nigohfamily.qobus.tj/3d</loc>
    <lastmod>2026-09-27</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
  <url>
    <loc>https://nigohfamily.qobus.tj/weevolve</loc>
    <lastmod>2026-09-27</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
</urlset>"""
    return Response(content=xml, media_type="application/xml; charset=utf-8")

@router.head("/health", include_in_schema=False)
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

def _site_page(request: Request, name: str, active: str, **context):
    return templates.TemplateResponse(
        request=request,
        name=f"site/{name}.html",
        context={
            "user": get_current_user(request),
            "app_version": settings.APP_VERSION,
            "active": active,
            "page_path": request.url.path if request.url.path != "/" else "/",
            **context,
        },
    )


@router.head("/", include_in_schema=False)
@router.get("/", response_class=HTMLResponse)
def landing_page(request: Request, db: Session = Depends(get_db)):
    reviews = [r.to_dict() for r in db.query(Review).order_by(Review.id.desc()).limit(6).all()]
    return _site_page(request, "home", "home", reviews=reviews)


@router.head("/features", include_in_schema=False)
@router.get("/features", response_class=HTMLResponse)
def features_page(request: Request):
    return _site_page(request, "features", "features")


@router.head("/how-it-works", include_in_schema=False)
@router.get("/how-it-works", response_class=HTMLResponse)
def how_it_works_page(request: Request):
    return _site_page(request, "how", "how")


@router.head("/3d", include_in_schema=False)
@router.head("/nigoh3d", include_in_schema=False)
@router.get("/3d", response_class=HTMLResponse)
@router.get("/nigoh3d", response_class=HTMLResponse)
def nigoh_3d_presentation(request: Request):
    return templates.TemplateResponse(request=request, name="nigoh3d.html", context={})

@router.head("/weevolve", include_in_schema=False)
@router.head("/evolve", include_in_schema=False)
@router.get("/weevolve", response_class=HTMLResponse)
@router.get("/evolve", response_class=HTMLResponse)
def weevolve_showcase_page(request: Request):
    return templates.TemplateResponse(request=request, name="weevolve.html", context={})

# Google Search Console EXACT file verification (strict matching to pass security anti-hacking probe)
@router.head("/googleee0fc42c18bef62a.html", include_in_schema=False)
@router.get("/googleee0fc42c18bef62a.html", response_class=Response)
def google_verification_exact():
    return Response(
        content="google-site-verification: googleee0fc42c18bef62a.html\n",
        media_type="text/plain; charset=utf-8"
    )

# Google Search Console verification token for the URL-prefix property.
@router.head("/google4e211d699041db6f.html", include_in_schema=False)
@router.get("/google4e211d699041db6f.html", response_class=Response)
def google_verification_url_prefix():
    return Response(
        content="google-site-verification: google4e211d699041db6f.html\n",
        media_type="text/plain; charset=utf-8"
    )
