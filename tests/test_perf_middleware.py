"""Файл: санҷишҳои суръати middleware — омор дар замина ва кэши файлҳои static."""

# Run from anywhere: make the project root importable and the working directory.
import os as _os, sys as _sys
_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

import threading
import time

from fastapi.testclient import TestClient

import app.main as main
from app.core.config import settings

PASSED = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    """Як шартро месанҷад ва натиҷаро чоп мекунад; хато бошад, санҷиш қатъ мешавад."""
    global PASSED
    if not ok:
        raise AssertionError(f"FAIL {name} {detail}")
    PASSED += 1
    print(f"ok  {name}")


def run_checks() -> None:
    """Ҳамаи сенарияҳоро бе навиштан ба базаи воқеӣ иҷро мекунад."""
    calls = []

    def fake_log(db, ip, path, user_agent, event_type="page_view", version=""):
        """Ба ҷои база зангро бо thread-и иҷро сабт мекунад."""
        calls.append({"path": path, "thread": threading.current_thread().name,
                      "event": event_type, "version": version, "ua": user_agent})

    original = main.log_analytics_event
    main.log_analytics_event = fake_log
    try:
        # Бе `with` — startup (init_db) иҷро намешавад ва база дахл намебинад.
        client = TestClient(main.app)

        # 1. Саҳифаҳои се забон ҳисоб мешаванд.
        for path in ("/", "/ru", "/en", "/features", "/ru/faq", "/en/security"):
            calls.clear()
            r = client.get(path, headers={"User-Agent": "perf-test"})
            check(f"{path} -> 200", r.status_code == 200, str(r.status_code))
            check(f"{path} counted once", len(calls) == 1, str(calls))
            check(f"{path} path recorded", calls[0]["path"] == path, str(calls))
            check(f"{path} version", calls[0]["version"] == settings.APP_VERSION)
            check(f"{path} user agent", calls[0]["ua"] == "perf-test")

        # 2. Омор дар thread-и дигар (threadpool) навишта мешавад, на дар event loop.
        calls.clear()
        client.get("/")
        check("analytics runs in a threadpool worker",
              bool(calls) and calls[0]["thread"].startswith("AnyIO worker"), str(calls))

        # 3. API ва static ҳисоб намешаванд.
        for path in ("/health", "/static/css/site.css", "/api/docs"):
            calls.clear()
            client.get(path)
            check(f"{path} not counted", calls == [], str(calls))

        # 4. Хатои омор ҷавобро вайрон намекунад.
        def broken_log(*a, **k):
            """Хатои базаро тақлид мекунад."""
            raise RuntimeError("db down")
        main.log_analytics_event = broken_log
        try:
            r = TestClient(main.app, raise_server_exceptions=False).get("/")
            check("page still 200 when analytics fails", r.status_code == 200, str(r.status_code))
        finally:
            main.log_analytics_event = fake_log

        # 5. Ҷавоб интизори навиштани омор намешавад.
        def slow_log(*a, **k):
            """Навиштани сусти базаро тақлид мекунад."""
            time.sleep(0.3)
            calls.append({"path": "slow"})
        main.log_analytics_event = slow_log
        try:
            calls.clear()
            r = client.get("/faq")
            check("slow analytics still recorded", calls == [{"path": "slow"}])
            check("security headers kept", r.headers.get("X-Content-Type-Options") == "nosniff")
        finally:
            main.log_analytics_event = fake_log

        # 6. Кэши браузер.
        r = client.get(f"/static/css/site.css?v={settings.APP_VERSION}")
        check("versioned static -> 200", r.status_code == 200)
        check("versioned static cached 1 year",
              r.headers.get("Cache-Control") == "public, max-age=31536000, immutable",
              str(r.headers.get("Cache-Control")))
        r = client.get("/static/css/site-fixes.css")
        check("unversioned static cached 1 hour",
              r.headers.get("Cache-Control") == "public, max-age=3600",
              str(r.headers.get("Cache-Control")))
        r = client.get("/")
        check("HTML pages not long-cached", "immutable" not in r.headers.get("Cache-Control", ""))
        r = client.get("/static/css/site.css?v=1", headers={"If-None-Match": client.get("/static/css/site.css?v=1").headers["etag"]})
        check("etag revalidation -> 304", r.status_code == 304, str(r.status_code))
    finally:
        main.log_analytics_event = original

    print(f"\nALL {PASSED} CHECKS PASSED")


if __name__ == "__main__":
    run_checks()
