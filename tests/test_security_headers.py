"""Файл: санҷиши сарлавҳаҳои амниятӣ — CSP, ҳимоя аз CSRF (Origin), no-store ва сиёсати иҷозатҳо."""

# Run from anywhere: make the project root importable and the working directory.
import os as _os, sys as _sys
_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

from fastapi.testclient import TestClient

import app.main as main
from app.core.security import rate_limiter

PASSED = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    """Як шартро месанҷад; хато бошад, санҷиш қатъ мешавад."""
    global PASSED
    if not ok:
        raise AssertionError(f"FAIL {name} {detail}")
    PASSED += 1
    print(f"ok  {name}")


def run_checks() -> None:
    """Ҳамаи сенарияҳоро бе навиштан ба база иҷро мекунад."""
    main.log_analytics_event = lambda *a, **k: None
    c = TestClient(main.app)

    # 1. Сарлавҳаҳо дар саҳифаҳои HTML.
    for path in ("/", "/ru/faq", "/en/contact", "/auth", "/privacy"):
        r = c.get(path)
        csp = r.headers.get("content-security-policy", "")
        check(f"{path} has CSP", "default-src 'self'" in csp and "object-src 'none'" in csp and "frame-ancestors 'self'" in csp, csp)
        check(f"{path} base-uri locked", "base-uri 'self'" in csp)
        check(f"{path} nosniff", r.headers.get("x-content-type-options") == "nosniff")
        check(f"{path} frame options", r.headers.get("x-frame-options") == "SAMEORIGIN")
        check(f"{path} legacy XSS filter off", r.headers.get("x-xss-protection") == "0")
        pp = r.headers.get("permissions-policy", "")
        check(f"{path} camera and geolocation off", "camera=()" in pp and "geolocation=()" in pp, pp)
    check("CSP allows Google Fonts", "https://fonts.googleapis.com" in main.CONTENT_SECURITY_POLICY and "https://fonts.gstatic.com" in main.CONTENT_SECURITY_POLICY)
    check("JSON has no CSP", "content-security-policy" not in c.get("/health").headers)

    # 2. no-store барои ҷавобҳои ҳассос, на барои static.
    check("auth API no-store", c.post("/api/auth/login", json={"email": "x", "password": "y"}).headers.get("cache-control") == "no-store")
    check("account page no-store", c.get("/account/security", follow_redirects=False).headers.get("cache-control") == "no-store")
    check("admin no-store", c.get("/admin", follow_redirects=False).headers.get("cache-control") == "no-store")
    check("mobile API no-store", c.get("/api/mobile/v3/auth/otp/config").headers.get("cache-control") == "no-store")
    check("static keeps cache", "no-store" not in c.get("/static/css/site.css?v=1").headers.get("cache-control", ""))
    check("home page not no-store", c.get("/").headers.get("cache-control") != "no-store")

    # 3. CSRF: Origin-и бегона рад мешавад.
    rate_limiter._history.clear()
    body = {"email": "nobody@example.com", "password": "whatever1"}
    r = c.post("/api/auth/login", json=body, headers={"Origin": "https://evil.example"})
    check("foreign origin -> 403", r.status_code == 403, str(r.status_code))
    r = c.post("/contact", data={"name": "a"}, headers={"Origin": "https://evil.example"})
    check("foreign origin form -> 403", r.status_code == 403)
    r = c.delete("/api/mobile/v2/children/1", headers={"Origin": "https://evil.example"})
    check("foreign origin delete -> 403", r.status_code == 403)
    r = c.post("/api/auth/login", json=body, headers={"Origin": "https://nigohfamily.qobus.tj"})
    check("official origin passes to the handler", r.status_code == 400, str(r.status_code))
    r = c.post("/api/auth/login", json=body, headers={"Origin": "http://testserver"})
    check("same host origin passes", r.status_code == 400, str(r.status_code))
    r = c.post("/api/auth/login", json=body)
    check("no origin (app, curl) passes", r.status_code == 400, str(r.status_code))
    r = c.get("/", headers={"Origin": "https://evil.example"})
    check("GET with foreign origin is fine", r.status_code == 200)
    r = c.post("/auth/apple/callback", data={}, headers={"Origin": "https://appleid.apple.com"}, follow_redirects=False)
    check("Apple form_post callback is exempt", r.status_code != 403, str(r.status_code))
    r = c.post("/auth/apple/callback", data={}, headers={"Origin": "null"}, follow_redirects=False)
    check("Apple callback with null origin is exempt", r.status_code != 403, str(r.status_code))
    r = c.post("/api/auth/login", json=body, headers={"Origin": "null"})
    check("null origin elsewhere -> 403", r.status_code == 403)
    rate_limiter._history.clear()
    print(f"\nALL {PASSED} CHECKS PASSED")


if __name__ == "__main__":
    run_checks()
