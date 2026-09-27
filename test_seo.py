import threading
import time
import urllib.request
import json
import xml.etree.ElementTree as ET
import uvicorn
from app.main import app
from app.database import init_db

def start_server():
    uvicorn.run(app, host="127.0.0.1", port=8892, log_level="warning")

def test_seo():
    print("=======================================================")
    print("🔍 NIGOH Family — SEO & Google Indexing Verification")
    print("=======================================================")

    init_db()
    t = threading.Thread(target=start_server, daemon=True)
    t.start()
    time.sleep(1.5)

    base = "http://127.0.0.1:8892"

    # 1. Test Landing Page SEO Meta
    print("1. Санҷиши Meta-тегҳои асосии SEO ва Googlebot...")
    with urllib.request.urlopen(f"{base}/") as resp:
        assert resp.status == 200
        html = resp.read().decode("utf-8")
        
        assert "<title>NIGOH Family" in html, "Title check failed"
        assert 'meta name="keywords"' in html, "Keywords meta tag missing"
        assert "nigoh family" in html.lower(), "Keywords brand 'nigoh family' missing"
        assert "нигоҳ family" in html.lower(), "Keywords brand 'нигоҳ family' missing"
        assert 'name="robots" content="index, follow' in html, "Robots index meta tag missing"
        assert 'name="googlebot" content="index, follow' in html, "Googlebot meta tag missing"
        assert 'rel="canonical" href="https://nigohfamily.qobus.tj/' in html, "Canonical URL missing"
        assert 'og:site_name" content="NIGOH Family"' in html, "OG Site Name missing"
        assert 'application/ld+json' in html, "JSON-LD structured schema missing"
        assert 'SoftwareApplication' in html, "SoftwareApplication schema missing"
        assert 'FAQPage' in html, "FAQPage schema missing"
        print("   ✅ Meta тегҳо, Title, Keywords ва Schema.org бо муваффақият санҷида шуданд!")

    # 2. Test robots.txt
    print("2. Санҷиши robots.txt барои Googlebot...")
    with urllib.request.urlopen(f"{base}/robots.txt") as resp:
        assert resp.status == 200
        txt = resp.read().decode("utf-8")
        assert "User-agent: Googlebot" in txt, "Googlebot directive missing in robots.txt"
        assert "Allow: /" in txt, "Allow directive missing"
        assert "Sitemap: https://nigohfamily.qobus.tj/sitemap.xml" in txt, "Sitemap URL missing in robots.txt"
        print("   ✅ robots.txt барои Googlebot ва ҷустуҷӯ комилан кушода ва дуруст аст!")

    # 3. Test sitemap.xml
    print("3. Санҷиши sitemap.xml...")
    with urllib.request.urlopen(f"{base}/sitemap.xml") as resp:
        assert resp.status == 200
        sitemap_xml = resp.read().decode("utf-8")
        assert "https://nigohfamily.qobus.tj/" in sitemap_xml, "Root URL missing in sitemap"
        assert "https://nigohfamily.qobus.tj/download/android" in sitemap_xml, "Download URL missing in sitemap"
        root = ET.fromstring(sitemap_xml)
        assert len(root) >= 4, "Sitemap url count is insufficient"
        print("   ✅ sitemap.xml синтаксиси дурусти XML дорад ва шомили ҳамаи саҳифаҳои асосӣ мебошад!")

    # 4. Test Health Endpoint
    print("4. Санҷиши саломатии система ва версия (/health)...")
    with urllib.request.urlopen(f"{base}/health") as resp:
        assert resp.status == 200
        health_data = json.loads(resp.read().decode("utf-8"))
        assert health_data["status"] == "healthy", f"Expected healthy, got {health_data['status']}"
        assert health_data["version"] == "2.9.0", f"Expected 2.9.0, got {health_data['version']}"
        assert health_data["apk_available"] is True, "APK not available"
        print(f"   ✅ Система солим (healthy), версия {health_data['version']}, файли фаъол: {health_data['active_apk']}!")

    print("\n=======================================================")
    print("🎉 ТАМОМИ САНҶИШҲОИ SEO БО МУВАФФАҚИЯТ ГУЗАШТАНД! (ALL PASSED)")
    print("=======================================================")

if __name__ == "__main__":
    test_seo()
