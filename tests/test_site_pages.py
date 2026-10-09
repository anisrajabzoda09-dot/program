"""Файл: санҷиши ҳамаи саҳифаҳои сайт бо се забон — ҷавоб, сарлавҳа, hreflang, footer ва sitemap."""

# Run from anywhere: make the project root importable and the working directory.
import os as _os, sys as _sys
_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

import re
from unittest.mock import patch

from fastapi.testclient import TestClient

import app.main as main
from app.core.releases import RELEASES

PASSED = 0
PAGES = ["/", "/features", "/how-it-works", "/security", "/faq", "/get",
         "/tips", "/compare", "/changelog", "/privacy", "/terms", "/contact"]
LANGS = {"tg": "", "ru": "/ru", "en": "/en"}


def check(name: str, ok: bool, detail: str = "") -> None:
    """Як шартро месанҷад; хато бошад, санҷиш қатъ мешавад."""
    global PASSED
    if not ok:
        raise AssertionError(f"FAIL {name} {detail}")
    PASSED += 1


def url(lang: str, page: str) -> str:
    """Роҳи саҳифаро барои забон месозад."""
    prefix = LANGS[lang]
    return (prefix or "") + ("" if page == "/" and prefix else page) or "/"


def run_checks() -> None:
    """Ҳар саҳифаро бо ҳар забон месанҷад."""
    main.log_analytics_event = lambda *a, **k: None  # омор ба база навишта нашавад
    c = TestClient(main.app)
    titles = {}
    for page in PAGES:
        for lang in LANGS:
            path = url(lang, page)
            r = c.get(path)
            check(f"{path} 200", r.status_code == 200, f"{path} {r.status_code}")
            html = r.text
            check(f"{path} lang attr", f'<html lang="{lang}">' in html, path)
            check(f"{path} rendered", "{{" not in html and "{%" not in html, path)
            title = re.search(r"<title>(.*?)</title>", html, re.S).group(1).strip()
            check(f"{path} has title", len(title) > 5, path)
            titles[(page, lang)] = title
            for code in LANGS:
                check(f"{path} hreflang {code}", f'hreflang="{code}"' in html, path)
            check(f"{path} canonical", f'<link rel="canonical" href="https://nigohfamily.qobus.tj{path}">' in html, path)
            for footer in ("/privacy", "/terms", "/contact", "/tips", "/compare", "/changelog"):
                check(f"{path} footer {footer}", f'href="{LANGS[lang]}{footer}"' in html, f"{path} {footer}")
            check(f"{path} one h1", html.count("<h1") == 1, f"{path} {html.count('<h1')}")
            for removed_content in ("demo.js", "demo.css", "mockup_map.png", 'class="nphone', 'class="web-mock', '482 913', 'Alijon is connected'):
                check(f"{path} no fabricated interface {removed_content}", removed_content not in html, path)
            check(f"{path} HEAD", c.head(path).status_code == 200, path)
    # Ҳар забон сарлавҳаи худро дорад (тарҷума фаромӯш нашудааст).
    for page in PAGES:
        check(f"{page} titles differ by language", len({titles[(page, l)] for l in LANGS}) == 3, str([titles[(page, l)] for l in LANGS]))

    for available in (True, False):
        release = {"available": available, "version": "2.18.0" if available else None,
                   "size_label": "72.4 MB" if available else None}
        with patch("app.routers.public.get_android_release", return_value=release):
            for lang in LANGS:
                home = c.get(url(lang, "/")).text
                download = c.get(url(lang, "/get")).text
                check(f"{lang} download control reflects availability {available}", ('class="release-download"' in home) == available)
                check(f"{lang} download status reflects availability {available}", ('class="release-unavailable"' in home) != available)
                check(f"{lang} real download QR", 'src="/api/qr/download"' in home)
                for page_html in (home, download):
                    check(f"{lang} actual APK size {available}", ("72.4 MB" in page_html) == available)
                    check(f"{lang} no guessed APK size {available}", "~77" not in page_html)
                    check(f"{lang} no null metadata {available}", ">None<" not in page_html)
                if available:
                    check(f"{lang} fallback APK version", ">2.18.0<" in home and ">2.18.0<" in download)

    # «Чӣ нав аст» ҳамаи версияҳоро нишон медиҳад.
    for lang in LANGS:
        html = c.get(url(lang, "/changelog")).text
        check(f"changelog {lang} lists every release", html.count('<li class="release') == len(RELEASES), str(html.count('<li class="release')))
        for rel in RELEASES:
            check(f"changelog {lang} {rel['version']} title", rel["title"][lang] in html, rel["version"])

    # Аниматсияи насб дар саҳифаҳои боргирӣ ва «чӣ тавр кор мекунад».
    for lang in LANGS:
        for page in ("/get", "/how-it-works"):
            html = c.get(url(lang, page)).text
            check(f"{lang}{page} install animation", "data-install-anim" in html and "install-anim.js" in html)

    # sitemap: ҳамаи суроғаҳо кор мекунанд ва ҳамаи саҳифаҳо дар он ҳастанд.
    xml = c.get("/sitemap.xml").text
    locs = re.findall(r"<loc>https://nigohfamily\.qobus\.tj(.*?)</loc>", xml)
    check("sitemap has all pages x3 + extras", len(locs) == len(PAGES) * 3 + 2, str(len(locs)))
    for loc in locs:
        path = loc or "/"
        status = c.get(path, follow_redirects=False).status_code
        check(f"sitemap {path}", status in (200, 302, 307), f"{path} {status}")
    check("sitemap hreflang links", xml.count('hreflang="x-default"') == len(PAGES) * 3)

    for path in ("/3d", "/nigoh3d", "/weevolve", "/evolve"):
        for method in (c.get, c.head):
            response = method(path, follow_redirects=False)
            check(f"{path} archived showcase redirects", response.status_code == 301 and response.headers.get("location") == "/")

    # Саҳифаи нодуруст 404 медиҳад.
    check("unknown page 404", c.get("/ru/nope").status_code == 404)
    print(f"ALL {PASSED} CHECKS PASSED")


if __name__ == "__main__":
    run_checks()
