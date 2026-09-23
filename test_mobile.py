import threading
import time
import urllib.request
import json
import uvicorn
from app.main import app

def start_server():
    uvicorn.run(app, host="127.0.0.1", port=8887, log_level="warning")

def run_mobile_tests():
    t = threading.Thread(target=start_server, daemon=True)
    t.start()
    time.sleep(1.5)

    base = "http://127.0.0.1:8887"

    print("1. Санҷиши саҳифаи мобилии /mobile...")
    req = urllib.request.Request(f"{base}/mobile")
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        html = resp.read().decode("utf-8")
        assert "НИГОҲ" in html
        assert "OTA Enabled" in html
        assert "qrcodejs" in html
    print("   Саҳифаи мобилӣ бомуваффақият кушода шуд (OK)!")

    print("2. Санҷиши санҷандаи версияи OTA (/api/mobile/version)...")
    with urllib.request.urlopen(f"{base}/api/mobile/version") as resp:
        assert resp.status == 200
        ver_data = json.loads(resp.read().decode("utf-8"))
        assert ver_data["version"] == "2.0.0"
        assert ver_data["channel"] == "stable"
    print("   Системаи санҷиши навсозии автоматии OTA кор мекунад (OK)!")

    print("3. Санҷиши бақайдгирии корбар бо Google...")
    g_data = json.dumps({
        "full_name": "Падари Мобилӣ",
        "email": f"parent_mob_{int(time.time())}@gmail.com",
        "avatar": "https://lh3.googleusercontent.com/a/default"
    }).encode("utf-8")
    req = urllib.request.Request(f"{base}/api/auth/google", data=g_data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        cookie = resp.headers.get("Set-Cookie")
        assert cookie is not None
    print("   Воридшавӣ бо Google тасдиқ шуд (OK)!")

    headers = {"Cookie": cookie, "Content-Type": "application/json"}

    print("4. Санҷиши интихоби нақш: Волидайн (POST /api/mobile/role-select)...")
    role_data = json.dumps({"role": "parent"}).encode("utf-8")
    req = urllib.request.Request(f"{base}/api/mobile/role-select", data=role_data, headers=headers)
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        u_data = json.loads(resp.read().decode("utf-8"))
        assert u_data["user"]["role"] == "parent"
    print("   Интихоби нақш санҷида шуд (OK)!")

    print("5. Санҷиши сабти фарзанд бо интихоби Писар 👦 ё Духтар 👧...")
    child_data = json.dumps({
        "name": "Алиҷон",
        "gender": "boy",
        "age": 11,
        "device_name": "Samsung Galaxy A54"
    }).encode("utf-8")
    req = urllib.request.Request(f"{base}/api/mobile/setup-child", data=child_data, headers=headers)
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        ch_resp = json.loads(resp.read().decode("utf-8"))
        assert ch_resp["child"]["name"] == "Алиҷон"
        assert ch_resp["child"]["gender"] == "boy"
        assert ch_resp["child"]["pairing_code"].startswith("NIGOH-")
        pair_code = ch_resp["child"]["pairing_code"]
    print("   Фарзанд (Писар) бомуваффақият сабт ва рамзи QR эҷод шуд (OK)!")

    print("6. Санҷиши пайвастшавӣ (QR Pairing)...")
    pair_data = json.dumps({"pairing_code": pair_code}).encode("utf-8")
    req = urllib.request.Request(f"{base}/api/mobile/pair", data=pair_data, headers=headers)
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        p_res = json.loads(resp.read().decode("utf-8"))
        assert p_res["child"]["is_paired"] == 1
    print("   Пайвастшавӣ бо рамзи QR комилан дуруст кор мекунад (OK)!")

    print("7. Санҷиши гирифтани ҳолат ва рӯйхати барномаҳо (/api/mobile/status)...")
    req = urllib.request.Request(f"{base}/api/mobile/status", headers=headers)
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        st = json.loads(resp.read().decode("utf-8"))
        assert len(st["apps"]) >= 8
        print(f"   {len(st['apps'])} барнома барои идоракунӣ мавҷуд аст (TikTok, PUBG, YouTube ва ғ.)")

    print("8. Санҷиши бастани (маҳкам кардани) барнома (TikTok lock/unlock)...")
    toggle_data = json.dumps({"package_name": "com.zhiliaoapp.musically", "is_blocked": True}).encode("utf-8")
    req = urllib.request.Request(f"{base}/api/mobile/apps/toggle", data=toggle_data, headers=headers)
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        t_res = json.loads(resp.read().decode("utf-8"))
        assert t_res["is_blocked"] is True
    print("   Барномаи TikTok маҳкам карда шуд (OK)!")

    print("9. Санҷиши гузоштани лимити вақт барои барнома (YouTube limit 30m)...")
    limit_data = json.dumps({"package_name": "com.google.android.youtube", "daily_limit_minutes": 30}).encode("utf-8")
    req = urllib.request.Request(f"{base}/api/mobile/apps/limit", data=limit_data, headers=headers)
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        l_res = json.loads(resp.read().decode("utf-8"))
        assert l_res["daily_limit_minutes"] == 30
    print("   Лимити 30 дақиқа барои YouTube гузошта шуд (OK)!")

    print("10. Санҷиши чати оилавӣ ва паёми овозӣ (/api/mobile/chat/send)...")
    # Send text message
    chat_text_data = json.dumps({"message_type": "text", "content": "Салом писарам, дарсҳоят чӣ хел?", "duration_sec": 0}).encode("utf-8")
    req = urllib.request.Request(f"{base}/api/mobile/chat/send", data=chat_text_data, headers=headers)
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        msg_res = json.loads(resp.read().decode("utf-8"))
        assert msg_res["message"]["message_type"] == "text"
        assert "дарсҳоят" in msg_res["message"]["content"]
    
    # Send voice message
    chat_voice_data = json.dumps({"message_type": "voice", "content": "Паёми овозӣ аз волидайн", "duration_sec": 12}).encode("utf-8")
    req = urllib.request.Request(f"{base}/api/mobile/chat/send", data=chat_voice_data, headers=headers)
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        voice_res = json.loads(resp.read().decode("utf-8"))
        assert voice_res["message"]["message_type"] == "voice"
        assert voice_res["message"]["duration_sec"] == 12

    print("   Чати матнӣ ва паёми овозӣ (voice message) бомуваффақият сабт ва қабул шуданд (OK)!")

    print("\n=======================================================")
    print(" 🎉 ТАМОМИ САНҶИШҲОИ МОБИЛӢ (MOBILE + OTA + APK) БО МУВАФФАҚИЯТ АНҶОМ ЁФТАНД!")
    print(" 🎉 ТАМОМИ САНҶИШҲОИ МОБИЛӢ (MOBILE + OTA + APK + CHAT/VOICE) БО МУВАФФАҚИЯТ АНҶОМ ЁФТАНД!")
    print("=======================================================")

if __name__ == "__main__":
    run_mobile_tests()

