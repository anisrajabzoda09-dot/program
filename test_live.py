import threading
import time
import urllib.request
import urllib.parse
import http.cookiejar
import json
import uvicorn
from app.main import app

def start_server():
    uvicorn.run(app, host="127.0.0.1", port=8888, log_level="warning")

def run_tests():
    t = threading.Thread(target=start_server, daemon=True)
    t.start()
    time.sleep(1.5)

    base = "http://127.0.0.1:8888"

    print("1. Санҷиши саҳифаи асосии сайт (GET /)...")
    req = urllib.request.Request(f"{base}/")
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        html = resp.read().decode("utf-8")
        assert "НИГОҲ FAMILY" in html
        assert "Дар бораи барнома" in html
        assert "Отзывҳо" in html
        assert "Боргирии Android" in html
        assert "18+" not in html, "Дар сайт набояд 18+ бошад"
    print("   Саҳифаи асосӣ бомуваффақият кушода шуд!")

    print("2. Санҷиши саҳифаи воридшавӣ (GET /auth)...")
    with urllib.request.urlopen(f"{base}/auth") as resp:
        assert resp.status == 200
        html = resp.read().decode("utf-8")
        assert "Google" in html
    print("   Саҳифаи /auth дуруст кор мекунад!")

    print("3. Санҷиши бақайдгирӣ бо Email (POST /api/auth/register)...")
    ts = int(time.time())
    data = json.dumps({
        "full_name": "Падари Санҷишӣ",
        "email": f"padar_live_{ts}@example.com",
        "password": "mypassword123"
    }).encode("utf-8")
    req = urllib.request.Request(f"{base}/api/auth/register", data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        res_json = json.loads(resp.read().decode("utf-8"))
        assert res_json["status"] == "success"
        assert res_json["redirect"] == "/#download"
        cookie = resp.headers.get("Set-Cookie")
        assert cookie is not None
    print("   Бақайдгирӣ муваффақона анҷом ёфт ва ба /#download равона кард!")

    print("4. Санҷиши воридшавӣ тавассути Google (POST /api/auth/google)...")
    data = json.dumps({
        "full_name": "Падар аз Google",
        "email": f"padar_google_{ts}@gmail.com",
        "avatar": "https://lh3.googleusercontent.com/a/default"
    }).encode("utf-8")
    req = urllib.request.Request(f"{base}/api/auth/google", data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        res_json = json.loads(resp.read().decode("utf-8"))
        assert res_json["status"] == "success"
        assert res_json["redirect"] == "/#download"
    print("   Google Sign-In дуруст кор кард ва ба /#download равона намуд!")

    print("5. Санҷиши воридшавӣ бо Email ва Parol (POST /api/auth/login)...")
    login_data = json.dumps({
        "email": f"padar_live_{ts}@example.com",
        "password": "mypassword123"
    }).encode("utf-8")
    req = urllib.request.Request(f"{base}/api/auth/login", data=login_data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        res_json = json.loads(resp.read().decode("utf-8"))
        assert res_json["status"] == "success"
        assert res_json["redirect"] == "/#download"
    print("   Воридшавӣ бо почта ва парол дуруст кор кард!")

    print("6. Санҷиши боргирии расмии барномаи Android (GET /download/android)...")
    req = urllib.request.Request(f"{base}/download/android")
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        content_type = resp.headers.get("Content-Type")
        disposition = resp.headers.get("Content-Disposition")
        assert "application/vnd.android.package-archive" in content_type
        assert "Nigoh_Family_v2.4.0_Android.apk" in disposition
        content_bytes = resp.read()
        assert len(content_bytes) > 500
        # Check ZIP / APK magic header PK
        assert content_bytes[:2] == b'PK'
    print("   Боргирии бастаи расмии APK бомуваффақият санҷида шуд!")

    print("\n=======================================================")
    print(" 🎉 ТАМОМИ САНҶИШҲОИ LIVE БО МУВАФФАҚИЯТ АНҶОМ ЁФТАНД! (ALL PASSED)")
    print("=======================================================")

if __name__ == "__main__":
    run_tests()
