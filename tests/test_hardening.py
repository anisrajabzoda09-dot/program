"""Файл: санҷишҳои автоматии `test_hardening` ва сенарияҳои ёрирасони он."""

# Run from anywhere: make the project root importable and the working directory.
import os as _os, sys as _sys
_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)


import json
import threading
import time
import urllib.request

import uvicorn

from app.main import app
from app.core.config import settings


PORT = 8898
BASE = f"http://127.0.0.1:{PORT}"


def start_server():
    """Рафтори `start_server`-ро дар муҳити санҷишӣ месанҷад."""

    uvicorn.run(app, host="127.0.0.1", port=PORT, log_level="warning")


def get_json(path: str):
    """Рафтори `get_json`-ро дар муҳити санҷишӣ месанҷад."""

    with urllib.request.urlopen(f"{BASE}{path}") as response:
        assert response.status == 200
        return json.loads(response.read().decode("utf-8"))


def run_checks():
    """Ҳамаи сенарияҳои санҷиширо иҷро карда, додаҳои муваққатиро пок мекунад."""

    threading.Thread(target=start_server, daemon=True).start()
    for _ in range(30):
        try:
            get_json("/health")
            break
        except Exception:
            time.sleep(0.2)
    else:
        raise AssertionError("local API did not start")

    health = get_json("/health")
    assert health["status"] == "healthy"
    assert health["version_code"] == settings.APP_VERSION_CODE
    assert health["apk_available"] is True

    same_version = get_json(f"/api/mobile/version?current_version_code={settings.APP_VERSION_CODE}")
    assert same_version["version_code"] == settings.APP_VERSION_CODE
    assert same_version["update_available"] is False

    older_version = get_json("/api/mobile/version?current_version_code=24")
    assert older_version["update_available"] is True

    newer_version = get_json(f"/api/mobile/version?current_version_code={settings.APP_VERSION_CODE + 1}")
    assert newer_version["update_available"] is False

    schema = get_json("/openapi.json")
    paths = schema["paths"]
    expected = {
        "/api/v1/children/{child_id}/apps/",
        "/api/v1/children/{child_id}/apps/{package_name}/limits",
        "/api/v1/children/{child_id}/apps/report-usage",
        "/api/v1/children/{child_id}/requests/time-extension",
    }
    assert expected.issubset(paths)
    print("Hardening checks passed: health, strict version logic, and app-control routes.")


if __name__ == "__main__":
    run_checks()
