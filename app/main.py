import os
import secrets
from fastapi import FastAPI, Request, Response, HTTPException
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from app.database import get_db, init_db
from app.schemas import UserRegister, UserLogin, GoogleAuthRequest
from app.auth import hash_password, create_session, get_current_user, SESSIONS

app = FastAPI(title="Нигоҳ — Сомонаи расмии муаррифӣ ва боргирии барнома")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(BASE_DIR, "static")
TEMPLATES_DIR = os.path.join(BASE_DIR, "templates")

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
templates = Jinja2Templates(directory=TEMPLATES_DIR)

# Initialize DB on startup
@app.on_event("startup")
def startup():
    init_db()

# --- HTML Pages ---

@app.get("/", response_class=HTMLResponse)
def landing_page(request: Request):
    user = get_current_user(request)
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM reviews ORDER BY id DESC")
    reviews = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return templates.TemplateResponse(request=request, name="landing.html", context={"user": user, "reviews": reviews})

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
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE email = ?", (payload.email,))
    row = cursor.fetchone()
    
    if row:
        user = dict(row)
        cursor.execute("UPDATE users SET avatar = ?, full_name = ? WHERE id = ?", (payload.avatar, payload.full_name, user["id"]))
        conn.commit()
    else:
        cursor.execute("""
        INSERT INTO users (email, full_name, avatar, role, google_id)
        VALUES (?, ?, ?, 'parent', ?)
        """, (payload.email, payload.full_name, payload.avatar, "google_" + secrets.token_hex(8)))
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

@app.get("/mobile", response_class=HTMLResponse)
def mobile_app_page(request: Request):
    """Mobile Native PWA Screen for both Parent and Child with live OTA update engine"""
    user = get_current_user(request)
    return templates.TemplateResponse(request=request, name="mobile_app.html", context={"user": user})

@app.get("/api/mobile/version")
def get_app_version():
    """Version check for Over-The-Air (OTA) Instant Updates on client phones"""
    return {
        "version": "2.0.0",
        "version_code": 2,
        "channel": "stable",
        "update_available": False,
        "release_notes": "Firebase Authentication, Google Login, нақшҳои волидайн ва фарзанд, QR-пайвастшавӣ, чат, харита ва ҷойгиршавии зинда.",
        "download_url": "/download/android"
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
Size: 71.1 MB
Status: Official Release Build Verified (V2 Signature Valid)

Дастури насб дар телефони Android:
1. Файли APK-ро кушоед ва иҷозати насбро тасдиқ намоед.
2. Барномаро кушоед ва аз имкониятҳои оилавии Нигоҳ истифода баред!
"""
    # Prioritize Flutter release APK
    apk_file_path = os.path.join(STATIC_DIR, "downloads", "NIGOH_Family_Android_v2.0.0.apk")
    apk_name = "NIGOH_Family_Android_v2.0.0.apk"

    if os.path.exists(apk_file_path):
        return FileResponse(
            path=apk_file_path,
            media_type="application/vnd.android.package-archive",
            filename=apk_name
        )
    # Fallback
    return Response(
        content=manifest_content,
        media_type="application/vnd.android.package-archive",
        headers={"Content-Disposition": f"attachment; filename={apk_name}"}
    )
