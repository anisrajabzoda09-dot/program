import threading
import time
import urllib.request
import urllib.parse
import json
import uvicorn
from app.main import app
from app.database import init_db

def start_server():
    uvicorn.run(app, host="127.0.0.1", port=8889, log_level="warning")

def run_tests():
    print("1. Санҷиши пойгоҳи додаҳо (DB init)...")
    init_db()

    t = threading.Thread(target=start_server, daemon=True)
    t.start()
    time.sleep(1.5)

    base = "http://127.0.0.1:8889"

    print("2. Санҷиши саҳифаи асосӣ (GET /)...")
    req = urllib.request.Request(f"{base}/")
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        html = resp.read().decode("utf-8")
        assert "НИГОҲ FAMILY" in html
        assert "Отзывҳо" in html
        assert "Боргирии Android" in html
        assert "18+" not in html, "Калимаи '18+' набояд дар сайт бошад!"
    print("   Саҳифаи асосӣ дуруст кор мекунад (OK)!")

    print("3. Санҷиши саҳифаи бақайдгирӣ (GET /auth)...")
    with urllib.request.urlopen(f"{base}/auth") as resp:
        assert resp.status == 200
        html = resp.read().decode("utf-8")
        assert "Google" in html
    print("   Саҳифаи /auth дуруст кор мекунад (OK)!")

    print("4. Санҷиши бақайдгирӣ бо Email (POST /api/auth/register)...")
    ts = int(time.time())
    reg_data = json.dumps({
        "full_name": "Падари Намунавӣ",
        "email": f"padar_app_{ts}@example.com",
        "password": "secretpassword123"
    }).encode("utf-8")
    req = urllib.request.Request(f"{base}/api/auth/register", data=reg_data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        data = json.loads(resp.read().decode("utf-8"))
        assert data["status"] == "success"
        assert data["redirect"] == "/#download", f"Redirect бояд ба /#download бошад, на {data.get('redirect')}"
        session_cookie = resp.headers.get("Set-Cookie")
        assert session_cookie is not None
    print("   Бақайдгирӣ ба /#download равона мекунад (OK)!")

    print("5. Санҷиши воридшавӣ бо Email (POST /api/auth/login)...")
    login_data = json.dumps({
        "email": f"padar_app_{ts}@example.com",
        "password": "secretpassword123"
    }).encode("utf-8")
    req = urllib.request.Request(f"{base}/api/auth/login", data=login_data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        data = json.loads(resp.read().decode("utf-8"))
        assert data["status"] == "success"
        assert data["redirect"] == "/#download"
    print("   Воридшавӣ ба /#download равона мекунад (OK)!")

    print("6. Санҷиши воридшавӣ бо Google (POST /api/auth/google)...")
    google_data = json.dumps({
        "full_name": "Волидайни Google",
        "email": f"google_app_{ts}@gmail.com",
        "avatar": "https://lh3.googleusercontent.com/a/default-user"
    }).encode("utf-8")
    req = urllib.request.Request(f"{base}/api/auth/google", data=google_data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        data = json.loads(resp.read().decode("utf-8"))
        assert data["status"] == "success"
        assert data["redirect"] == "/#download"
    print("   Google Sign-In ба /#download равона мекунад (OK)!")

    print("7. Санҷиши саҳифаи асосӣ бо Session Cookie...")
    req = urllib.request.Request(f"{base}/", headers={"Cookie": session_cookie})
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        html = resp.read().decode("utf-8")
        assert "Шумо бомуваффақият ворид шудед!" in html
    print("   Саҳифаи асосӣ ҳолати корбари воридшударо дуруст нишон медиҳад (OK)!")

    print("8. Санҷиши боргирии расмии APK (GET /download/android)...")
    req = urllib.request.Request(f"{base}/download/android")
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        assert "application/vnd.android.package-archive" in resp.headers.get("Content-Type")
        content_bytes = resp.read()
        assert len(content_bytes) > 500
        assert content_bytes[:2] == b'PK'
    print("   Боргирии APK санҷида шуд (OK)!")

    print("\n=======================================================")
    print(" 🎉 ТАМОМИ САНҶИШҲОИ test_app.py БО МУВАФФАҚИЯТ ГУЗАШТАНД! (ALL PASSED)")
    print("=======================================================")

if __name__ == "__main__":
    run_tests()
