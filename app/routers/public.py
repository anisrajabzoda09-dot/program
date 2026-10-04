"""Файл: саҳифаҳои оммавӣ, SEO, health ва endpoint-ҳои verification."""

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
    """Дархости `GET /robots.txt`-ро барои get robots txt коркард мекунад."""

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

SITE_LANGS = ("tg", "ru", "en")
_SITE = "https://nigohfamily.qobus.tj"

# Саҳифаҳои сайт, ки бо се забон ҳастанд: (роҳ, афзалият, басомади тағйир).
_SITEMAP_PAGES = (
    ("/", "1.0", "weekly"),
    ("/features", "0.9", "weekly"),
    ("/how-it-works", "0.8", "monthly"),
    ("/get", "0.9", "weekly"),
    ("/security", "0.7", "monthly"),
    ("/faq", "0.8", "weekly"),
    ("/tips", "0.8", "monthly"),
    ("/compare", "0.7", "monthly"),
    ("/changelog", "0.6", "weekly"),
    ("/contact", "0.5", "yearly"),
    ("/privacy", "0.4", "yearly"),
    ("/terms", "0.4", "yearly"),
)

# Саҳифаҳое, ки танҳо як версия доранд.
_SITEMAP_SINGLE = (
    ("/download/android", "0.9", "weekly"),
    ("/auth", "0.5", "monthly"),
)


def _lang_url(lang: str, path: str) -> str:
    """Суроғаи пурраи саҳифаро барои забони додашуда месозад (тоҷикӣ бе пешванд)."""
    if lang == "tg":
        return _SITE + path
    return _SITE + f"/{lang}" + ("" if path == "/" else path)


def build_sitemap(lastmod: str) -> str:
    """XML-и sitemap-ро бо ҳамаи саҳифаҳо ва пайвандҳои hreflang байни забонҳо месозад."""
    parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
        'xmlns:xhtml="http://www.w3.org/1999/xhtml">',
    ]
    for path, priority, freq in _SITEMAP_PAGES:
        alternates = "".join(
            f'\n    <xhtml:link rel="alternate" hreflang="{code}" href="{_lang_url(code, path)}"/>'
            for code in SITE_LANGS
        ) + f'\n    <xhtml:link rel="alternate" hreflang="x-default" href="{_lang_url("tg", path)}"/>'
        for lang in SITE_LANGS:
            parts.append(
                f"  <url>\n    <loc>{_lang_url(lang, path)}</loc>\n    <lastmod>{lastmod}</lastmod>"
                f"\n    <changefreq>{freq}</changefreq>\n    <priority>{priority}</priority>{alternates}\n  </url>"
            )
    for path, priority, freq in _SITEMAP_SINGLE:
        parts.append(
            f"  <url>\n    <loc>{_SITE}{path}</loc>\n    <lastmod>{lastmod}</lastmod>"
            f"\n    <changefreq>{freq}</changefreq>\n    <priority>{priority}</priority>\n  </url>"
        )
    parts.append("</urlset>")
    return "\n".join(parts) + "\n"


@router.head("/sitemap.xml", include_in_schema=False)
@router.get("/sitemap.xml", response_class=Response)
def get_sitemap_xml():
    """Дархости `GET /sitemap.xml`: харитаи сайт бо се забон барои Google ва Yandex."""
    xml = build_sitemap(settings.SITE_UPDATED)
    return Response(content=xml, media_type="application/xml; charset=utf-8")

@router.head("/health", include_in_schema=False)
@router.get("/health")
def health_check(db: Session = Depends(get_db)):
    """Дархости `GET /health`-ро барои health check коркард мекунад."""
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



def _site_page(request: Request, name: str, active: str, lang: str = "tg", **context):
    """Саҳифаи оммавиро бо template ва забони мувофиқи URL месозад."""
    path = request.url.path
    base_path = path
    for prefix in ("/ru", "/en"):
        if path == prefix or path.startswith(prefix + "/"):
            base_path = path[len(prefix):] or "/"
    template = f"site/{name}.html" if lang == "tg" else f"site/{lang}/{name}.html"
    return templates.TemplateResponse(
        request=request,
        name=template,
        context={
            "user": get_current_user(request),
            "app_version": settings.APP_VERSION,
            "active": active,
            "lang": lang,
            "lang_prefix": "" if lang == "tg" else f"/{lang}",
            "base_path": base_path,
            "page_path": path,
            **context,
        },
    )


_PAGES = [
    ("", "home", "home"),
    ("/features", "features", "features"),
    ("/how-it-works", "how", "how"),
    ("/security", "security", "security"),
    ("/faq", "faq", "faq"),
    ("/get", "get", "get"),
]


def _register_translated(lang: str) -> None:
    """Маълумоти ёрирасони register translated-ро омода карда, ба caller бармегардонад."""

    for suffix, name, active in _PAGES:
        def view(request: Request, db: Session = Depends(get_db), _name=name, _active=active):
            """Маълумоти ёрирасони view-ро омода карда, ба caller бармегардонад."""

            extra = {}
            if _name == "home":
                extra["reviews"] = [r.to_dict() for r in db.query(Review).order_by(Review.id.desc()).limit(6).all()]
            return _site_page(request, _name, _active, lang=lang, **extra)

        route = f"/{lang}{suffix}" or f"/{lang}"
        router.add_api_route(route, view, methods=["GET"], response_class=HTMLResponse, include_in_schema=False)
        router.add_api_route(route, view, methods=["HEAD"], response_class=HTMLResponse, include_in_schema=False)
        if suffix == "":
            router.add_api_route(f"/{lang}/", view, methods=["GET"], response_class=HTMLResponse, include_in_schema=False)


for _lang in ("ru", "en"):
    _register_translated(_lang)



@router.head("/", include_in_schema=False)
@router.get("/", response_class=HTMLResponse)
def landing_page(request: Request, db: Session = Depends(get_db)):
    """Дархости `GET /`-ро барои landing саҳифа коркард мекунад."""

    reviews = [r.to_dict() for r in db.query(Review).order_by(Review.id.desc()).limit(6).all()]
    return _site_page(request, "home", "home", reviews=reviews)


@router.head("/features", include_in_schema=False)
@router.get("/features", response_class=HTMLResponse)
def features_page(request: Request):
    """Дархости `GET /features`-ро барои features саҳифа коркард мекунад."""

    return _site_page(request, "features", "features")


@router.head("/how-it-works", include_in_schema=False)
@router.get("/how-it-works", response_class=HTMLResponse)
def how_it_works_page(request: Request):
    """Дархости `GET /how-it-works`-ро барои how it works саҳифа коркард мекунад."""

    return _site_page(request, "how", "how")


@router.head("/security", include_in_schema=False)
@router.get("/security", response_class=HTMLResponse)
def security_page(request: Request):
    """Дархости `GET /security`-ро барои security саҳифа коркард мекунад."""

    return _site_page(request, "security", "security")


@router.head("/faq", include_in_schema=False)
@router.get("/faq", response_class=HTMLResponse)
def faq_page(request: Request):
    """Дархости `GET /faq`-ро барои faq саҳифа коркард мекунад."""

    return _site_page(request, "faq", "faq")


@router.head("/get", include_in_schema=False)
@router.get("/get", response_class=HTMLResponse)
def get_app_page(request: Request):
    """Дархости `GET /get`-ро барои get app саҳифа коркард мекунад."""

    return _site_page(request, "get", "get")


@router.head("/3d", include_in_schema=False)
@router.head("/nigoh3d", include_in_schema=False)
@router.get("/3d", response_class=HTMLResponse)
@router.get("/nigoh3d", response_class=HTMLResponse)
def nigoh_3d_presentation(request: Request):
    """Дархости `GET /3d`-ро барои nigoh 3d presentation коркард мекунад."""

    return templates.TemplateResponse(request=request, name="nigoh3d.html", context={})

@router.head("/weevolve", include_in_schema=False)
@router.head("/evolve", include_in_schema=False)
@router.get("/weevolve", response_class=HTMLResponse)
@router.get("/evolve", response_class=HTMLResponse)
def weevolve_showcase_page(request: Request):
    """Дархости `GET /weevolve`-ро барои weevolve showcase саҳифа коркард мекунад."""

    return templates.TemplateResponse(request=request, name="weevolve.html", context={})

# Google Search Console EXACT file verification (strict matching to pass security anti-hacking probe)
@router.head("/googleee0fc42c18bef62a.html", include_in_schema=False)
@router.get("/googleee0fc42c18bef62a.html", response_class=Response)
def google_verification_exact():
    """Дархости `GET /googleee0fc42c18bef62a.html`-ро барои Google verification exact коркард мекунад."""

    return Response(
        content="google-site-verification: googleee0fc42c18bef62a.html\n",
        media_type="text/plain; charset=utf-8"
    )

# Google Search Console verification token for the URL-prefix property.
@router.head("/google4e211d699041db6f.html", include_in_schema=False)
@router.get("/google4e211d699041db6f.html", response_class=Response)
def google_verification_url_prefix():
    """Дархости `GET /google4e211d699041db6f.html`-ро барои Google verification url prefix коркард мекунад."""

    return Response(
        content="google-site-verification: google4e211d699041db6f.html\n",
        media_type="text/plain; charset=utf-8"
    )
