"""Integration checks for the real Google OAuth browser flow."""

import json
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.client import HTTPResponse
from unittest.mock import patch

import uvicorn

from app.core.config import settings
from app.main import app


PORT = 8897
BASE = f"http://127.0.0.1:{PORT}"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp: HTTPResponse, code, msg, headers, newurl):
        return None


def open_without_redirects(request):
    opener = urllib.request.build_opener(NoRedirect)
    try:
        return opener.open(request)
    except urllib.error.HTTPError as error:
        return error


def start_server():
    uvicorn.run(app, host="127.0.0.1", port=PORT, log_level="warning")


def wait_for_server():
    for _ in range(30):
        try:
            urllib.request.urlopen(f"{BASE}/health")
            return
        except Exception:
            time.sleep(0.2)
    raise AssertionError("OAuth test server did not start")


def run_checks():
    settings.GOOGLE_CLIENT_ID = "oauth-test-client.apps.googleusercontent.com"
    settings.GOOGLE_CLIENT_SECRET = "oauth-test-secret"
    settings.GOOGLE_REDIRECT_URI = f"{BASE}/auth/google/callback"

    threading.Thread(target=start_server, daemon=True).start()
    wait_for_server()

    login = open_without_redirects(urllib.request.Request(f"{BASE}/auth/google/login?next=%2F"))
    assert login.status == 307
    location = login.headers["Location"]
    query = urllib.parse.parse_qs(urllib.parse.urlsplit(location).query)
    state = query["state"][0]
    assert query["client_id"][0] == settings.GOOGLE_CLIENT_ID
    assert query["scope"][0] == "openid email profile"
    assert query["redirect_uri"][0] == settings.GOOGLE_REDIRECT_URI
    cookie_header = login.headers["Set-Cookie"]
    assert f"google_oauth_state={state}" in cookie_header

    userinfo = {
        "sub": "google-sub-oauth-test",
        "email": f"oauth_flow_{int(time.time())}@example.com",
        "email_verified": True,
        "name": "OAuth Test Parent",
        "picture": "https://example.com/avatar.png",
    }
    callback_request = urllib.request.Request(
        f"{BASE}/auth/google/callback?code=test-code&state={urllib.parse.quote(state)}",
        headers={"Cookie": cookie_header.split(";", 1)[0]},
    )
    with patch("app.routers.auth._exchange_google_code", return_value=userinfo):
        callback = open_without_redirects(callback_request)
    assert callback.status == 303
    assert callback.headers["Location"] == "/"
    assert settings.SESSION_COOKIE_NAME in callback.headers["Set-Cookie"]

    api_request = urllib.request.Request(
        f"{BASE}/api/auth/google",
        data=json.dumps({"token": "x" * 32}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with patch("app.routers.auth._google_userinfo_from_access_token", return_value=userinfo):
        api_response = urllib.request.urlopen(api_request)
    assert api_response.status == 200
    assert json.loads(api_response.read())["status"] == "success"
    print("Google OAuth checks passed: redirect, CSRF state, callback session, and token API.")


if __name__ == "__main__":
    run_checks()
