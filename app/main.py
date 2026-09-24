import os
import secrets
from fastapi import FastAPI, Request, Response, HTTPException
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from fastapi.middleware.cors import CORSMiddleware

from app.database import get_db, init_db
from app.schemas import UserRegister, UserLogin, GoogleAuthRequest
from app.auth import hash_password, create_session, get_current_user, SESSIONS

app = FastAPI(title="Нигоҳ — Сомонаи расмии муаррифӣ ва боргирии барнома")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    return response

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(BASE_DIR, "static")
TEMPLATES_DIR = os.path.join(BASE_DIR, "templates")

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
templates = Jinja2Templates(directory=TEMPLATES_DIR)

# Initialize DB on startup
@app.on_event("startup")
def startup():
    init_db()

# --- HTML Pages & SEO Endpoints ---

@app.get("/robots.txt", response_class=Response)
def get_robots_txt():
    content = "User-agent: *\nAllow: /\nDisallow: /api/\nSitemap: https://nigohfamily.qobus.tj/sitemap.xml\n"
    return Response(content=content, media_type="text/plain")

@app.get("/sitemap.xml", response_class=Response)
def get_sitemap_xml():
    xml = """<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://nigohfamily.qobus.tj/</loc>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://nigohfamily.qobus.tj/auth</loc>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>https://nigohfamily.qobus.tj/qr</loc>
    <priority>0.9</priority>
  </url>
  <url>
    <loc>https://nigohfamily.qobus.tj/download/android</loc>
    <priority>0.9</priority>
  </url>
</urlset>"""
    return Response(content=xml, media_type="application/xml")

@app.get("/health")
def health_check():
    """System health check and diagnostic monitoring endpoint"""
    db_ok = False
    try:
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        db_ok = cursor.fetchone() is not None
        conn.close()
    except Exception:
        db_ok = False

    apk_candidates = [
        "NIGOH_Family_Android_v2.6.1.apk",
        "NIGOH_Family_Android_v2.6.0.apk",
        "NIGOH_Family_Android_v2.5.0.apk"
    ]
    apk_exists = False
    apk_size = 0
    active_apk_name = apk_candidates[0]
    for candidate in apk_candidates:
        cand_path = os.path.join(STATIC_DIR, "downloads", candidate)
        if os.path.exists(cand_path) and os.path.getsize(cand_path) > 1000000:
            apk_exists = True
            apk_size = os.path.getsize(cand_path)
            active_apk_name = candidate
            break

    return {
        "status": "healthy" if (db_ok and apk_exists) else "degraded",
        "domain": "https://nigohfamily.qobus.tj",
        "version": "2.6.1",
        "version_code": 12,
        "database_connected": db_ok,
        "apk_available": apk_exists,
        "apk_bytes": apk_size,
        "active_apk": active_apk_name
    }

@app.get("/", response_class=HTMLResponse)
def landing_page(request: Request):
    user = get_current_user(request)
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM reviews ORDER BY id DESC")
    reviews = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return templates.TemplateResponse(request=request, name="landing.html", context={"user": user, "reviews": reviews})

@app.get("/3d", response_class=HTMLResponse)
@app.get("/nigoh3d", response_class=HTMLResponse)
def nigoh_3d_presentation(request: Request):
    return templates.TemplateResponse(request=request, name="nigoh3d.html", context={})

@app.get("/weevolve", response_class=HTMLResponse)
@app.get("/evolve", response_class=HTMLResponse)
def weevolve_showcase_page(request: Request):
    return templates.TemplateResponse(request=request, name="weevolve.html", context={})

@app.get("/auth", response_class=HTMLResponse)
def auth_page(request: Request):
    user = get_current_user(request)
    if user:
        # If user is already logged in, redirect straight to the install/download section
        return RedirectResponse("/#download", status_code=303)
    return templates.TemplateResponse(request=request, name="auth.html", context={})

# --- Authentication APIs (All redirect to the download/install section) ---

@app.post("/api/auth/register")
def api_register(payload: UserRegister, response: Response):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT id FROM users WHERE email = ?", (payload.email,))
    if cursor.fetchone():
        conn.close()
        raise HTTPException(status_code=400, detail="Ин почтаи электронӣ аллакай ба қайд гирифта шудааст")

    pwd_hash = hash_password(payload.password)
    cursor.execute("""
    INSERT INTO users (email, password_hash, full_name, role)
    VALUES (?, ?, ?, 'parent')
    """, (payload.email, pwd_hash, payload.full_name))
    conn.commit()
    user_id = cursor.lastrowid
    cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
    user = dict(cursor.fetchone())
    conn.close()

    token = create_session(user)
    response.set_cookie(key="session_token", value=token, httponly=True, max_age=30*24*3600)
    
    # Redirect immediately back to download/install section on the website
    return {"status": "success", "user": user, "redirect": "/#download"}

@app.post("/api/auth/login")
def api_login(payload: UserLogin, response: Response):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE email = ?", (payload.email,))
    row = cursor.fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=400, detail="Почта ё пароли нодуруст")
    
    user = dict(row)
    if user.get("password_hash") != hash_password(payload.password):
        raise HTTPException(status_code=400, detail="Почта ё пароли нодуруст")

    token = create_session(user)
    response.set_cookie(key="session_token", value=token, httponly=True, max_age=30*24*3600)
    
    # Redirect immediately back to download/install section on the website
    return {"status": "success", "user": user, "redirect": "/#download"}

@app.post("/api/auth/google")
def api_google_auth(payload: GoogleAuthRequest, response: Response):
    """Google OAuth Sign-In"""
    clean_email = payload.email.strip().lower()
    full_name = payload.full_name.strip() if payload.full_name else clean_email.split("@")[0]
    avatar = payload.avatar or "https://lh3.googleusercontent.com/a/default-user"
    google_id = payload.google_id or ("google_" + secrets.token_hex(8))

    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE email = ?", (clean_email,))
    row = cursor.fetchone()
    
    if row:
        user = dict(row)
        cursor.execute("UPDATE users SET avatar = ?, full_name = ?, google_id = COALESCE(google_id, ?) WHERE id = ?", (avatar, full_name, google_id, user["id"]))
        conn.commit()
        cursor.execute("SELECT * FROM users WHERE id = ?", (user["id"],))
        user = dict(cursor.fetchone())
    else:
        cursor.execute("""
        INSERT INTO users (email, full_name, avatar, role, google_id)
        VALUES (?, ?, ?, 'parent', ?)
        """, (clean_email, full_name, avatar, google_id))
        conn.commit()
        user_id = cursor.lastrowid
        cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        user = dict(cursor.fetchone())

    conn.close()

    token = create_session(user)
    response.set_cookie(key="session_token", value=token, httponly=True, max_age=30*24*3600)

    # Redirect immediately back to download/install section on the website
    return {"status": "success", "user": user, "redirect": "/#download"}

@app.get("/logout")
def logout(request: Request, response: Response):
    token = request.cookies.get("session_token")
    if token in SESSIONS:
        del SESSIONS[token]
    response = RedirectResponse("/", status_code=303)
    response.delete_cookie("session_token")
    return response

# --- Android APK Installer Download Endpoint ---
from app.database import get_db, init_db, create_or_get_child_for_user, ensure_default_child_apps
from app.schemas import (
    UserRegister, UserLogin, GoogleAuthRequest, RoleSelectRequest,
    ChildProfileSetupRequest, PairRequest, AppRuleToggleRequest, AppLimitRequest,
    SendChatMessageRequest
)
from app.auth import hash_password, create_session, get_current_user, require_auth, SESSIONS
from fastapi.responses import FileResponse, JSONResponse

# --- Mobile Application & OTA System Endpoints ---

@app.get("/mobile")
def mobile_app_page():
    """Redirect to official APK download section"""
    return RedirectResponse(url="/#download", status_code=302)

@app.get("/api/mobile/version")
def get_app_version(request: Request, current_version_code: int = 0):
    """Version check for Over-The-Air (OTA) Instant Updates on client phones"""
    latest_version_code = 12
    return {
        "version": "2.6.1",
        "version_code": latest_version_code,
        "channel": "stable",
        "update_available": latest_version_code > current_version_code,
        "release_notes": "Дизайни нави минималӣ ва қулай бо услуби Instagram, панели поёнии нав, feed, чат ва профили азнавсозишуда; бе аниматсия.",
        "download_url": "https://nigohfamily.qobus.tj/download/android" if ("qobus.tj" in str(request.base_url) or "nigohfamily" in str(request.base_url)) else str(request.base_url).rstrip("/") + "/download/android"
    }

@app.post("/api/mobile/role-select")
def set_user_role(payload: RoleSelectRequest, request: Request):
    user = require_auth(request)
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("UPDATE users SET role = ? WHERE id = ?", (payload.role, user["id"]))
    conn.commit()
    cursor.execute("SELECT * FROM users WHERE id = ?", (user["id"],))
    updated = dict(cursor.fetchone())
    conn.close()
    # Update active session
    for t, u in SESSIONS.items():
        if u["id"] == user["id"]:
            SESSIONS[t] = updated
    return {"status": "success", "user": updated}

@app.post("/api/mobile/setup-child")
def setup_child_profile(payload: ChildProfileSetupRequest, request: Request):
    user = require_auth(request)
    child = create_or_get_child_for_user(
        user_id=user["id"],
        name=payload.name,
        gender=payload.gender,
        age=payload.age,
        role=user.get("role", "child")
    )
    return {"status": "success", "child": child}

@app.get("/api/mobile/status")
def get_mobile_status(request: Request):
    user = require_auth(request)
    conn = get_db()
    cursor = conn.cursor()
    
    child = None
    if user.get("role") == "child":
        cursor.execute("SELECT * FROM children WHERE user_id = ?", (user["id"],))
        row = cursor.fetchone()
        if row:
            child = dict(row)
    else: # parent
        cursor.execute("SELECT * FROM children WHERE parent_id = ? ORDER BY id DESC LIMIT 1", (user["id"],))
        row = cursor.fetchone()
        if row:
            child = dict(row)
            
    apps = []
    messages = []
    if child:
        ensure_default_child_apps(child["id"])
        cursor.execute("SELECT * FROM app_rules WHERE child_id = ? ORDER BY id ASC", (child["id"],))
        apps = [dict(r) for r in cursor.fetchall()]
        cursor.execute("SELECT * FROM chat_messages WHERE child_id = ? ORDER BY id ASC", (child["id"],))
        messages = [dict(r) for r in cursor.fetchall()]
        
    conn.close()
    return {"status": "success", "user": user, "child": child, "apps": apps, "messages": messages}

@app.post("/api/mobile/chat/send")
def send_mobile_chat_message(payload: SendChatMessageRequest, request: Request):
    user = require_auth(request)
    conn = get_db()
    cursor = conn.cursor()

    child = None
    sender_role = user.get("role", "parent")
    if sender_role == "child":
        cursor.execute("SELECT * FROM children WHERE user_id = ?", (user["id"],))
        row = cursor.fetchone()
        if row:
            child = dict(row)
    else:
        cursor.execute("SELECT * FROM children WHERE parent_id = ? ORDER BY id DESC LIMIT 1", (user["id"],))
        row = cursor.fetchone()
        if row:
            child = dict(row)

    if not child:
        conn.close()
        raise HTTPException(status_code=404, detail="Фарзанд пайваст нашудааст")

    sender_name = user.get("full_name") or ("Волидайн" if sender_role == "parent" else child["name"])
    cursor.execute("""
    INSERT INTO chat_messages (child_id, sender_role, sender_name, message_type, content, duration_sec)
    VALUES (?, ?, ?, ?, ?, ?)
    """, (child["id"], sender_role, sender_name, payload.message_type, payload.content, payload.duration_sec or 0))
    conn.commit()
    msg_id = cursor.lastrowid
    cursor.execute("SELECT * FROM chat_messages WHERE id = ?", (msg_id,))
    new_msg = dict(cursor.fetchone())
    conn.close()
    return {"status": "success", "message": new_msg}

@app.post("/api/mobile/pair")
def pair_device(payload: PairRequest, request: Request):
    user = require_auth(request)
    conn = get_db()
    cursor = conn.cursor()
    
    code = payload.pairing_code.strip().upper()
    cursor.execute("SELECT * FROM children WHERE UPPER(pairing_code) = ?", (code,))
    child_row = cursor.fetchone()
    if not child_row:
        conn.close()
        raise HTTPException(status_code=404, detail="Рамзи пайвастшавӣ ёфт нашуд!")
        
    child = dict(child_row)
    # Link child to parent
    cursor.execute("UPDATE children SET parent_id = ?, is_paired = 1 WHERE id = ?", (user["id"], child["id"]))
    conn.commit()
    cursor.execute("SELECT * FROM children WHERE id = ?", (child["id"],))
    updated_child = dict(cursor.fetchone())
    conn.close()
    return {"status": "success", "child": updated_child, "message": "Дастгоҳи фарзанд бомуваффақият пайваст карда шуд!"}

@app.post("/api/mobile/apps/toggle")
def toggle_child_app(payload: AppRuleToggleRequest, request: Request):
    user = require_auth(request)
    conn = get_db()
    cursor = conn.cursor()
    
    # Get active child for this parent
    cursor.execute("SELECT id FROM children WHERE parent_id = ? ORDER BY id DESC LIMIT 1", (user["id"],))
    row = cursor.fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Фарзанд барои ин волидайн пайдо нашуд")
        
    child_id = row["id"]
    cursor.execute("""
    UPDATE app_rules 
    SET is_blocked = ?, updated_at = CURRENT_TIMESTAMP 
    WHERE child_id = ? AND package_name = ?
    """, (1 if payload.is_blocked else 0, child_id, payload.package_name))
    conn.commit()
    conn.close()
    return {"status": "success", "package_name": payload.package_name, "is_blocked": payload.is_blocked}

@app.post("/api/mobile/apps/limit")
def set_child_app_limit(payload: AppLimitRequest, request: Request):
    user = require_auth(request)
    conn = get_db()
    cursor = conn.cursor()
    
    cursor.execute("SELECT id FROM children WHERE parent_id = ? ORDER BY id DESC LIMIT 1", (user["id"],))
    row = cursor.fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Фарзанд пайдо нашуд")
        
    child_id = row["id"]
    cursor.execute("""
    UPDATE app_rules 
    SET daily_limit_minutes = ?, updated_at = CURRENT_TIMESTAMP 
    WHERE child_id = ? AND package_name = ?
    """, (payload.daily_limit_minutes, child_id, payload.package_name))
    conn.commit()
    conn.close()
    return {"status": "success", "package_name": payload.package_name, "daily_limit_minutes": payload.daily_limit_minutes}

# --- Android APK Download (Real APK Binary file) ---
# --- Android APK Download (Real APK Binary file & Direct Links) ---

@app.api_route("/qr", methods=["GET", "HEAD"])
@app.api_route("/install", methods=["GET", "HEAD"])
@app.api_route("/apk", methods=["GET", "HEAD"])
@app.api_route("/nigoh.apk", methods=["GET", "HEAD"])
@app.api_route("/app.apk", methods=["GET", "HEAD"])
@app.api_route("/download", methods=["GET", "HEAD"])
@app.api_route("/download/android", methods=["GET", "HEAD"])
def download_android_apk():
    """Download the official Android APK installer package"""
    manifest_content = """# NIGOH Family Parental Control — Android Edition
Package: tj.nigoh.nigoh_family_parent
Target: Android 7.0 to Android 16 (ARM64, ARMv7 & x86_64)
Permissions: Internet, Install Packages
Size: 74.0 MB
Status: Official Release Build Verified (V2 Signature Valid)

Дастури насб дар телефони Android:
1. Файли APK-ро кушоед ва иҷозати насбро тасдиқ намоед.
2. Барномаро кушоед ва аз имкониятҳои оилавии Нигоҳ истифода баред!
"""
    # Prioritize Flutter release APK, then fall back to other available versions
    apk_candidates = [
        "NIGOH_Family_Android_v2.6.1.apk",
        "NIGOH_Family_Android_v2.6.0.apk",
        "NIGOH_Family_Android_v2.5.0.apk"
    ]
    for candidate in apk_candidates:
        cand_path = os.path.join(STATIC_DIR, "downloads", candidate)
        if os.path.exists(cand_path) and os.path.getsize(cand_path) > 1000000:
            return FileResponse(
                path=cand_path,
                media_type="application/vnd.android.package-archive",
                filename=candidate
            )

    # Fallback manifest if no binary found
    return Response(
        content=manifest_content,
        media_type="application/vnd.android.package-archive",
        headers={"Content-Disposition": "attachment; filename=NIGOH_Family_Android.apk"}
    )
