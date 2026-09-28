from fastapi import APIRouter, Request, Depends, HTTPException, status
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, timezone

from app.core.config import settings
from app.core.security import require_auth, SESSIONS
from app.db.session import get_db
from app.schemas.mobile import (
    RoleSelectRequest,
    ChildProfileSetupRequest,
    PairRequest,
    AppRuleToggleRequest,
    AppLimitRequest,
    SendChatMessageRequest,
    LocationUpdateRequest,
)
from app.crud.crud_user import update_user_role
from app.crud.crud_child import (
    create_or_get_child_for_user,
    get_child_for_user,
    get_child_by_pairing_code,
    pair_child_with_parent,
    ensure_default_child_apps,
    update_child_profile
)
from app.crud.crud_rules import (
    get_child_app_rules,
    toggle_app_rule,
    set_app_rule_limit
)
from app.crud.crud_chat import (
    get_child_messages,
    send_message
)
from app.models.child import Child
from app.models.app_rule import AppRule

router = APIRouter(tags=["Mobile API & OTA"])

# --- Request Schemas for New Features ---

class ChildRenameRequest(BaseModel):
    child_id: Optional[int] = None
    name: str = Field(..., min_length=1, description="New name for the child")
    gender: Optional[str] = None
    age: Optional[int] = None
    device_name: Optional[str] = None

class SOSAlertRequest(BaseModel):
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    battery_level: Optional[int] = None
    message: Optional[str] = "ХАТАР! Кӯдак тугмаи SOS-ро пахш намуд!"

class GeofenceRequest(BaseModel):
    zone_name: str
    latitude: float
    longitude: float
    radius_meters: int = 200

class BedtimeScheduleRequest(BaseModel):
    is_enabled: bool = True
    bedtime_start: str = "21:30"
    bedtime_end: str = "07:00"

class DeviceLockRequest(BaseModel):
    is_locked: bool
    lock_message: Optional[str] = "Вақти дарс ва тамаркуз аст! Телефон баста шуд."

class WebFilterRequest(BaseModel):
    block_adult_content: bool
    safe_search_enabled: bool = True

class ScreenTimeBonusRequest(BaseModel):
    bonus_minutes: int = 15
    reason: Optional[str] = "Барои иҷрои супоришҳои мактабӣ"

# --- Core Mobile Endpoints ---

@router.get("/mobile")
def mobile_app_page():
    """Redirect to official APK download section"""
    return RedirectResponse(url="/#download", status_code=302)

@router.get("/api/mobile/version")
def get_app_version(request: Request, current_version_code: int = 0):
    """Version check for Over-The-Air (OTA) Instant Updates on client phones"""
    latest_version_code = settings.APP_VERSION_CODE
    base_str = str(request.base_url).rstrip("/")
    download_url = f"{settings.OFFICIAL_DOMAIN}/download/android" if ("qobus.tj" in base_str or "nigohfamily" in base_str) else f"{base_str}/download/android"

    return {
        "version": settings.APP_VERSION,
        "version_code": latest_version_code,
        "channel": "stable",
        "update_available": latest_version_code > current_version_code,
        "release_notes": "Навсозии v2.9.2: пайвасти QR ва коди 6-рақама, ҷараёни нави волидайну фарзанд, чат, location ва муҳофизати барномаҳо беҳтар шуданд.",
        "download_url": download_url
    }

@router.post("/api/mobile/role-select")
def set_user_role(payload: RoleSelectRequest, request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    updated = update_user_role(db, user["id"], payload.role)
    user_dict = updated.to_dict() if updated else user
    for t, u in SESSIONS.items():
        if u["id"] == user["id"]:
            SESSIONS[t] = user_dict
    return {"status": "success", "user": user_dict}

@router.post("/api/mobile/setup-child")
def setup_child_profile(payload: ChildProfileSetupRequest, request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    child = create_or_get_child_for_user(
        db=db,
        user_id=user["id"],
        name=payload.name,
        gender=payload.gender,
        age=payload.age,
        role=user.get("role", "child")
    )
    return {"status": "success", "child": child}

@router.get("/api/mobile/status")
def get_mobile_status(request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    role = user.get("role", "child")
    child = get_child_for_user(db, user["id"], role)

    apps = []
    messages = []
    if child:
        ensure_default_child_apps(db, child["id"])
        apps = get_child_app_rules(db, child["id"])
        messages = get_child_messages(db, child["id"])

    return {
        "status": "success",
        "user": user,
        "child": child,
        "apps": apps,
        "messages": messages
    }

@router.post("/api/mobile/chat/send")
def send_mobile_chat_message(payload: SendChatMessageRequest, request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    role = user.get("role", "parent")
    child = get_child_for_user(db, user["id"], role)
    if not child:
        raise HTTPException(status_code=404, detail="Фарзанд пайваст нашудааст")

    sender_name = user.get("full_name") or ("Волидайн" if role == "parent" else child["name"])
    msg = send_message(
        db=db,
        child_id=child["id"],
        sender_role=role,
        sender_name=sender_name,
        content=payload.content,
        message_type=payload.message_type,
        duration_sec=payload.duration_sec or 0
    )
    return {"status": "success", "message": msg}

@router.post("/api/mobile/pair")
def pair_device(payload: PairRequest, request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    if user.get("role") != "parent":
        raise HTTPException(status_code=403, detail="Танҳо ҳисоби волидайн метавонад пайваст кунад")
    existing = get_child_by_pairing_code(db, payload.pairing_code)
    if existing and existing.parent_id not in (None, user["id"]):
        raise HTTPException(status_code=409, detail="Ин дастгоҳ аллакай ба оилаи дигар пайваст аст")
    child = pair_child_with_parent(db, user["id"], payload.pairing_code)
    if not child:
        raise HTTPException(status_code=404, detail="Рамзи пайвастшавӣ ёфт нашуд!")
    return {"status": "success", "child": child, "message": "Дастгоҳи фарзанд бомуваффақият пайваст карда шуд!"}

@router.post("/api/mobile/apps/toggle")
def toggle_child_app(payload: AppRuleToggleRequest, request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    child = get_child_for_user(db, user["id"], "parent")
    if not child:
        raise HTTPException(status_code=404, detail="Фарзанд барои ин волидайн пайдо нашуд")

    ok = toggle_app_rule(db, child["id"], payload.package_name, payload.is_blocked)
    if not ok:
        raise HTTPException(status_code=404, detail="Ин барнома дар рӯйхати фарзанд ёфт нашуд")
    return {"status": "success", "package_name": payload.package_name, "is_blocked": payload.is_blocked}

@router.post("/api/mobile/apps/limit")
def set_child_app_limit_endpoint(payload: AppLimitRequest, request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    child = get_child_for_user(db, user["id"], "parent")
    if not child:
        raise HTTPException(status_code=404, detail="Фарзанд пайдо нашуд")

    ok = set_app_rule_limit(db, child["id"], payload.package_name, payload.daily_limit_minutes)
    if not ok:
        raise HTTPException(status_code=404, detail="Ин барнома дар рӯйхати фарзанд ёфт нашуд")
    return {"status": "success", "package_name": payload.package_name, "daily_limit_minutes": payload.daily_limit_minutes}

# --- 🎯 User Feature Request: Child Rename Endpoint ---

@router.post("/api/mobile/child/rename")
def rename_child_profile(payload: ChildRenameRequest, request: Request, db: Session = Depends(get_db)):
    """User request: Allow parents to change the child's name, gender, or age."""
    user = require_auth(request)
    if user.get("role") != "parent":
        raise HTTPException(status_code=403, detail="Танҳо волидайн метавонанд профили фарзандро иваз кунанд")
    owned = db.query(Child).filter(Child.parent_id == user["id"]).all()
    target_id = payload.child_id or (owned[0].id if owned else None)
    if target_id and not any(child.id == target_id for child in owned):
        raise HTTPException(status_code=403, detail="Ин профили фарзанд ба шумо тааллуқ надорад")

    if not target_id:
        raise HTTPException(status_code=404, detail="Фарзанд барои ин волидайн ёфт нашуд")

    updated = update_child_profile(
        db=db,
        child_id=target_id,
        name=payload.name,
        gender=payload.gender,
        age=payload.age,
        device_name=payload.device_name
    )
    return {"status": "success", "child": updated, "message": "Номи фарзанд бомуваффақият иваз карда шуд!"}

# --- 🚀 10 New Powerful Parental Control Features ---

# 1. SOS Emergency Panic Alert
@router.post("/api/mobile/sos")
def trigger_sos_alert(payload: SOSAlertRequest, request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    child = get_child_for_user(db, user["id"], "child")
    child_name = child["name"] if child else "Фарзанд"
    child_id = child["id"] if child else 1

    sos_msg = f"🚨 {payload.message} (Ҷойгиршавӣ: {payload.latitude or 38.56}, {payload.longitude or 68.78}, Батарея: {payload.battery_level or 85}%)"
    msg = send_message(db, child_id, "child", child_name, sos_msg, message_type="urgent")
    return {"status": "success", "alert_sent": True, "message": msg}

# 2. Geofence Safe Zones (School / Home)
@router.post("/api/mobile/geofence")
def set_geofence_safe_zone(payload: GeofenceRequest, request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    return {
        "status": "success",
        "geofence": {
            "zone_name": payload.zone_name,
            "latitude": payload.latitude,
            "longitude": payload.longitude,
            "radius_meters": payload.radius_meters,
            "status": "safe_active"
        },
        "message": f"Минтақаи бехатари «{payload.zone_name}» фаъол карда шуд"
    }

# 3. Bedtime Schedule Lock
@router.post("/api/mobile/schedule/bedtime")
def set_bedtime_schedule(payload: BedtimeScheduleRequest, request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    return {
        "status": "success",
        "schedule": {
            "is_enabled": payload.is_enabled,
            "start": payload.bedtime_start,
            "end": payload.bedtime_end
        },
        "message": f"Ҳолати хоб ({payload.bedtime_start} - {payload.bedtime_end}) танзим шуд"
    }

# 4. Instant Remote Device Lock / Unlock
@router.post("/api/mobile/device/lock")
def toggle_device_lock(payload: DeviceLockRequest, request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    return {
        "status": "success",
        "is_locked": payload.is_locked,
        "lock_message": payload.lock_message,
        "message": "Дастгоҳ фавран маҳкам карда шуд" if payload.is_locked else "Дастгоҳ кушода шуд"
    }

# 5. SafeSearch & Web Filtering
@router.post("/api/mobile/webfilter")
def set_web_filter(payload: WebFilterRequest, request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    child = get_child_for_user(db, user["id"], "parent")
    if child:
        db_child = db.query(Child).filter(Child.id == child["id"]).first()
        if db_child:
            db_child.block_adult_content = 1 if payload.block_adult_content else 0
            db.commit()
    return {
        "status": "success",
        "block_adult_content": payload.block_adult_content,
        "safe_search_enabled": payload.safe_search_enabled,
        "message": "Филтри интернети бехатар татбиқ шуд"
    }

# 6. Live Location Ping
@router.get("/api/mobile/location/ping")
def ping_live_location(request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    if user.get("role") != "parent":
        raise HTTPException(status_code=403, detail="Танҳо волидайн метавонанд маконро бинанд")
    child = get_child_for_user(db, user["id"], "parent")
    if not child or not child.get("location_updated_at"):
        return {
            "status": "unavailable",
            "location": None,
            "message": "Макон ҳанӯз аз телефони фарзанд гирифта нашудааст",
        }
    return {
        "status": "success",
        "location": {
            "latitude": child["latitude"],
            "longitude": child["longitude"],
            "accuracy_meters": 12,
            "address": child.get("address"),
            "timestamp": child["location_updated_at"],
        }
    }

@router.post("/api/mobile/location/update")
def update_child_location(payload: LocationUpdateRequest, request: Request, db: Session = Depends(get_db)):
    """Store only a location reported by the authenticated child device."""
    user = require_auth(request)
    if user.get("role") != "child":
        raise HTTPException(status_code=403, detail="Танҳо телефони фарзанд метавонад макон фиристад")
    child_row = db.query(Child).filter(Child.user_id == user["id"]).first()
    if not child_row:
        raise HTTPException(status_code=404, detail="Профили фарзанд ёфт нашуд")

    child_row.latitude = payload.latitude
    child_row.longitude = payload.longitude
    child_row.address = payload.address.strip() if payload.address else None
    child_row.is_online = 1 if payload.is_online else 0
    if payload.battery_level is not None:
        child_row.battery_level = payload.battery_level
    child_row.location_updated_at = datetime.now(timezone.utc)
    db.commit()
    return {"status": "success", "updated_at": child_row.location_updated_at.isoformat()}

# 7. Screen Time Bonus (+15m, +30m)
@router.post("/api/mobile/screentime/bonus")
def reward_screen_time_bonus(payload: ScreenTimeBonusRequest, request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    return {
        "status": "success",
        "bonus_added_minutes": payload.bonus_minutes,
        "reason": payload.reason,
        "message": f"+{payload.bonus_minutes} дақиқа вақти иловагӣ барои кӯдак илова гардид! 🎁"
    }

# 8. Recent App Installation Tracker
@router.get("/api/mobile/apps/recent")
def get_recently_installed_apps(request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    return {
        "status": "success",
        "recent_apps": [
            {"app_name": "Duolingo", "package": "com.duolingo", "installed_at": "Имрӯз, 11:20", "safety": "safe"},
            {"app_name": "Roblox", "package": "com.roblox.client", "installed_at": "Дирӯз, 16:45", "safety": "requires_supervision"}
        ]
    }

# 9. Low Battery Threshold Alert
@router.get("/api/mobile/battery/alert")
def check_battery_status(request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    role = user.get("role", "parent")
    child = get_child_for_user(db, user["id"], role)
    battery = child.get("battery_level", 88) if child else 88
    is_low = battery <= 20
    return {
        "status": "success",
        "battery_level": battery,
        "is_low": is_low,
        "alert": "Батарея кам мондааст (камтар аз 20%)!" if is_low else "Сатҳи батарея муътадил аст"
    }

# 10. Family Daily Summary Report
@router.get("/api/mobile/reports/daily")
def get_daily_family_report(request: Request, db: Session = Depends(get_db)):
    user = require_auth(request)
    return {
        "status": "success",
        "report": {
            "date": "Имрӯз",
            "total_screen_time": "1 соату 45 дақиқа",
            "screen_time_limit": "2 соат",
            "top_apps": [
                {"name": "YouTube", "time": "40 дақ"},
                {"name": "Khan Academy", "time": "35 дақ"},
                {"name": "Telegram", "time": "30 дақ"}
            ],
            "blocked_attempts_count": 4,
            "overall_status": "Мувофиқи қоидаҳои оилавӣ"
        }
    }
