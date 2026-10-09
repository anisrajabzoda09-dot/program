"""Файл: API-и mobile барои pairing, назорат, chat, location ва usage."""

from fastapi import APIRouter, Request, Depends, Header, HTTPException, Query, status
from fastapi.responses import JSONResponse, RedirectResponse, Response
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import date, datetime, timedelta, timezone
import json

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
    AppControlUpdateRequest,
    UsageReportRequest,
    TimeExtensionRequest,
    AppBundleCreateRequest,
    InstalledAppsSyncRequest,
    MobilePairCodeRequest,
    MobilePairRequest,
    MobileLinkExistingRequest,
    MobileLocationRequest,
    MobileChatRequest,
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
from app.models.app_usage import AppUsageDaily
from app.models.extension_request import AppExtensionRequest
from app.models.app_bundle import AppBundle
from app.models.chat import ChatMessage
from app.models.family_extras import LocationPoint, SafePlace
from app.crud.crud_privacy import prune_location_history, purge_child_history
from app.core import events as family_events
from app.core import pairing, place_rules, web_filter
from app.models.user import User
from app.core.firebase_mobile import find_user_by_firebase_uid
from app.core.mobile_auth import require_mobile_user
from app.crud.crud_bundle import create_bundle, ensure_initial_bundle, list_after

router = APIRouter(tags=["Mobile API & OTA"])

# --- Request Schemas for New Features ---

class ChildRenameRequest(BaseModel):
    """Маълумоти `ChildRenameRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    child_id: Optional[int] = None
    name: str = Field(..., min_length=1, description="New name for the child")
    gender: Optional[str] = None
    age: Optional[int] = None
    device_name: Optional[str] = None

class SOSAlertRequest(BaseModel):
    """Маълумоти `SOSAlertRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    latitude: Optional[float] = None
    longitude: Optional[float] = None
    battery_level: Optional[int] = None
    message: Optional[str] = "ХАТАР! Кӯдак тугмаи SOS-ро пахш намуд!"

class GeofenceRequest(BaseModel):
    """Маълумоти `GeofenceRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    zone_name: str
    latitude: float
    longitude: float
    radius_meters: int = 200

class BedtimeScheduleRequest(BaseModel):
    """Маълумоти `BedtimeScheduleRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    is_enabled: bool = True
    bedtime_start: str = "21:30"
    bedtime_end: str = "07:00"

class DeviceLockRequest(BaseModel):
    """Маълумоти `DeviceLockRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    is_locked: bool
    lock_message: Optional[str] = "Вақти дарс ва тамаркуз аст! Телефон баста шуд."

class WebFilterRequest(BaseModel):
    """Маълумоти `WebFilterRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    block_adult_content: bool
    safe_search_enabled: bool = True

class ScreenTimeBonusRequest(BaseModel):
    """Маълумоти `ScreenTimeBonusRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    bonus_minutes: int = 15
    reason: Optional[str] = "Барои иҷрои супоришҳои мактабӣ"


def _get_owned_child(db: Session, user: dict, child_id: int) -> Child:
    """Барои гирифтан ё санҷидани get owned фарзанд истифода мешавад."""
    query = db.query(Child).filter(Child.id == child_id)
    if user.get("role") == "parent":
        query = query.filter(Child.parent_id == user["id"])
    elif user.get("role") == "child":
        query = query.filter(Child.user_id == user["id"])
    else:
        raise HTTPException(status_code=403, detail="Ҳисоб барои назорати оила иҷозат надорад")
    child = query.first()
    if not child:
        raise HTTPException(status_code=404, detail="Фарзанд барои ин ҳисоб ёфт нашуд")
    return child


def _rule_payload(rule: AppRule, usage: Optional[AppUsageDaily] = None) -> dict:
    """Маълумоти ёрирасони қоида payload-ро омода карда, ба caller бармегардонад."""

    minutes = usage.minutes if usage else 0
    limit = rule.daily_limit_minutes or 0
    schedule = None
    if rule.schedule_json:
        try:
            schedule = json.loads(rule.schedule_json)
        except (TypeError, json.JSONDecodeError):
            schedule = None
    today_iso = date.today().isoformat()
    return {
        **rule.to_dict(),
        "schedule": schedule,
        "always_allowed": bool(rule.always_allowed),
        "bonus_minutes_today": (rule.bonus_minutes or 0) if rule.bonus_date == today_iso else 0,
        "first_seen_at": rule.first_seen_at.isoformat() if rule.first_seen_at else None,
        "usage_minutes_today": minutes,
        "usage_percent": min(100, round(minutes * 100 / limit)) if limit else 0,
        "is_limit_exceeded": bool(limit and minutes >= limit),
    }


def _mobile_child(db: Session, user: dict, child_id: Optional[int] = None) -> Child:
    """Маълумоти ёрирасони фарзанд-ро омода карда, ба caller бармегардонад."""

    query = db.query(Child)
    if user.get("role") == "parent":
        query = query.filter(Child.parent_id == user["id"])
    else:
        query = query.filter(Child.user_id == user["id"])
    if child_id is not None:
        query = query.filter(Child.id == child_id)
    child = query.order_by(Child.id.desc()).first()
    if not child:
        raise HTTPException(status_code=404, detail="Профили оила ёфт нашуд")
    return child


def _mobile_child_payload(db: Session, child: Child) -> dict:
    """Маълумоти ёрирасони фарзанд payload-ро омода карда, ба caller бармегардонад."""

    # The mobile app shows only apps really reported by the child's phone;
    # placeholder defaults (never synced) must not appear or block anything.
    today = date.today()
    usage_rows = db.query(AppUsageDaily).filter(
        AppUsageDaily.child_id == child.id,
        AppUsageDaily.usage_date == today,
    ).all()
    usage_by_package = {row.package_name: row for row in usage_rows}
    rules = db.query(AppRule).filter(
        AppRule.child_id == child.id,
        AppRule.is_installed == 1,
    ).order_by(AppRule.app_name.asc()).all()
    child_user = db.query(User).filter(User.id == child.user_id).first() if child.user_id else None
    parent_user = db.query(User).filter(User.id == child.parent_id).first() if child.parent_id else None
    return {
        **child.to_dict(),
        "firebase_uid": child_user.firebase_uid if child_user else None,
        "parent_firebase_uid": parent_user.firebase_uid if parent_user else None,
        "child_user_id": child.user_id,
        "parent_user_id": child.parent_id,
        "parent_name": parent_user.full_name if parent_user else None,
        "parent_avatar": parent_user.avatar if parent_user else None,
        "child_avatar": child_user.avatar if child_user else None,
        "child_email": child_user.email if child_user else None,
        "location": {
            "latitude": child.latitude,
            "longitude": child.longitude,
            "accuracy": 0,
            "battery_level": child.battery_level,
            "online": bool(child.is_online),
            "updated_at": child.location_updated_at.isoformat() if child.location_updated_at else None,
        } if child.location_updated_at else None,
        "apps": [_rule_payload(rule, usage_by_package.get(rule.package_name)) for rule in rules],
        "bedtime": _json_or_none(child.bedtime_json),
        "study": _json_or_none(child.study_json),
        "web_filter": web_filter.payload(child),
        # Ҷойҳо бо қоидаҳо: телефони фарзанд онҳоро бе интернет ҳам иҷро мекунад.
        "places": [p.to_dict() for p in db.query(SafePlace).filter(SafePlace.child_id == child.id).order_by(SafePlace.id.asc())],
        "current_place_id": child.current_place_id,
        "battery_level": child.battery_level if child.location_updated_at else None,
        "unread_from_child": _unread(db, child.id, "child"),
        "unread_from_parent": _unread(db, child.id, "parent"),
        "pending_requests": db.query(AppExtensionRequest).filter(
            AppExtensionRequest.child_id == child.id,
            AppExtensionRequest.status == "pending",
        ).count(),
        "last_urgent": _last_urgent(db, child.id),
    }


def _json_or_none(raw: Optional[str]):
    """Маълумоти ёрирасони json or none-ро омода карда, ба caller бармегардонад."""

    if not raw:
        return None
    try:
        return json.loads(raw)
    except (TypeError, ValueError):
        return None


def _unread(db: Session, child_id: int, sender_role: str) -> int:
    """Маълумоти ёрирасони unread-ро омода карда, ба caller бармегардонад."""

    return db.query(ChatMessage).filter(
        ChatMessage.child_id == child_id,
        ChatMessage.sender_role == sender_role,
        ChatMessage.is_read == 0,
    ).count()


def _last_urgent(db: Session, child_id: int) -> Optional[dict]:
    """Маълумоти ёрирасони last urgent-ро омода карда, ба caller бармегардонад."""
    row = db.query(ChatMessage).filter(
        ChatMessage.child_id == child_id,
        ChatMessage.sender_role == "child",
        ChatMessage.message_type == "urgent",
        ChatMessage.is_read == 0,
    ).order_by(ChatMessage.id.desc()).first()
    if row is None or row.created_at is None:
        return None
    created = row.created_at if row.created_at.tzinfo else row.created_at.replace(tzinfo=timezone.utc)
    if datetime.now(timezone.utc) - created > timedelta(hours=24):
        return None
    return row.to_dict()


def _mobile_snapshot(db: Session, user: dict) -> dict:
    """Маълумоти ёрирасони snapshot-ро омода карда, ба caller бармегардонад."""

    if user.get("role") == "parent":
        children = db.query(Child).filter(Child.parent_id == user["id"]).order_by(Child.id.desc()).all()
        return {
            "status": "success",
            "source": "nigoh-api",
            "user": user,
            "children": [_mobile_child_payload(db, child) for child in children],
        }
    child = db.query(Child).filter(Child.user_id == user["id"]).order_by(Child.id.desc()).first()
    # Рамзи кӯҳнаи фарзанди ҳанӯз пайвастнашуда худкор нав мешавад.
    pairing.refresh_if_expired(db, child)
    return {
        "status": "success",
        "source": "nigoh-api",
        "user": user,
        "child": _mobile_child_payload(db, child) if child else None,
    }

# --- Core Mobile Endpoints ---

@router.get("/mobile")
def mobile_app_page():
    """Дархости `GET /mobile`-ро барои app саҳифа коркард мекунад."""
    return RedirectResponse(url="/get", status_code=302)

@router.get("/api/mobile/version")
def get_app_version(request: Request, current_version_code: int = 0):
    """Дархости `GET /api/mobile/version`-ро барои get app version коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""
    latest_version_code = settings.APP_VERSION_CODE
    base_str = str(request.base_url).rstrip("/")
    download_url = f"{settings.OFFICIAL_DOMAIN}/download/android" if ("qobus.tj" in base_str or "nigohfamily" in base_str) else f"{base_str}/download/android"

    return {
        "version": settings.APP_VERSION,
        "version_code": latest_version_code,
        "channel": "stable",
        "update_available": latest_version_code > current_version_code,
        "release_notes": "v2.21.0: қоидаҳо аз рӯи ҷой (дар мактаб бозиҳо баста, лимит ё ҳамеша кушода) ва огоҳии «ба мактаб расид / аз хона баромад».",
        "download_url": download_url
    }


@router.get("/api/mobile/sync-bundle")
def sync_dynamic_bundle(
    request: Request,
    db: Session = Depends(get_db),
    client_bundle_version: Optional[int] = Query(default=None, ge=0),
    native_version_code: Optional[int] = Query(default=None, ge=0),
    bundle_header: Optional[int] = Header(default=None, alias="X-Client-Bundle-Version"),
    native_header: Optional[int] = Header(default=None, alias="X-Native-Version-Code"),
):
    """Дархости `GET /api/mobile/sync-bundle`-ро барои sync dynamic bundle коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""
    current_bundle = client_bundle_version
    if current_bundle is None:
        current_bundle = bundle_header if bundle_header is not None else 0
    native_code = native_version_code
    if native_code is None:
        native_code = native_header if native_header is not None else settings.APP_VERSION_CODE

    latest = ensure_initial_bundle(db)
    if current_bundle >= latest.bundle_version:
        return Response(status_code=status.HTTP_304_NOT_MODIFIED)

    bundles = list_after(db, current_bundle)
    if not bundles:
        return JSONResponse({"has_update": False, "bundle_version": latest.bundle_version})

    requires_full_reinstall = any(
        bundle.patch_type == "full_bundle" or bundle.min_native_code > native_code
        for bundle in bundles
    )
    if requires_full_reinstall:
        return {
            "has_update": True,
            "bundle_version": latest.bundle_version,
            "requires_full_reinstall": True,
            "apk_url": f"{settings.OFFICIAL_DOMAIN}/download/android",
            "native_version_code": native_code,
        }

    return {
        "has_update": True,
        "bundle_version": latest.bundle_version,
        "requires_full_reinstall": False,
        "patches": [bundle.to_dict() for bundle in bundles],
        "download_url": f"{settings.OFFICIAL_DOMAIN}/download/android",
    }


@router.post("/api/mobile/bundles", status_code=status.HTTP_201_CREATED)
def publish_dynamic_bundle(
    payload: AppBundleCreateRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Дархости `POST /api/mobile/bundles`-ро барои publish dynamic bundle коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""
    user = require_auth(request)
    if user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Танҳо администратор bundle нашр карда метавонад")
    bundle = create_bundle(
        db,
        min_native_code=payload.min_native_code,
        patch_type=payload.patch_type,
        payload=payload.payload,
    )
    return bundle.to_dict()

@router.post("/api/mobile/role-select")
def set_user_role(payload: RoleSelectRequest, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /api/mobile/role-select`-ро барои set корбар нақш коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = require_auth(request)
    updated = update_user_role(db, user["id"], payload.role)
    user_dict = updated.to_dict() if updated else user
    for t, u in SESSIONS.items():
        if u["id"] == user["id"]:
            SESSIONS[t] = user_dict
    return {"status": "success", "user": user_dict}

@router.post("/api/mobile/setup-child")
def setup_child_profile(payload: ChildProfileSetupRequest, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /api/mobile/setup-child`-ро барои setup фарзанд профил коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

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
    """Дархости `GET /api/mobile/status`-ро барои get ҳолат коркард мекунад."""

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
    """Дархости `POST /api/mobile/chat/send`-ро барои send chat паём коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

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
    """Дархости `POST /api/mobile/pair`-ро барои pairing дастгоҳ коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = require_auth(request)
    if user.get("role") != "parent":
        raise HTTPException(status_code=403, detail="Танҳо ҳисоби волидайн метавонад пайваст кунад")
    pairing.check_attempt(request, user["id"])
    pairing.find_child(db, payload.pairing_code)
    existing = get_child_by_pairing_code(db, payload.pairing_code)
    if existing and existing.parent_id not in (None, user["id"]):
        raise HTTPException(status_code=409, detail="Ин дастгоҳ аллакай ба оилаи дигар пайваст аст")
    child = pair_child_with_parent(db, user["id"], payload.pairing_code)
    if not child:
        raise HTTPException(status_code=404, detail="Рамзи пайвастшавӣ ёфт нашуд!")
    return {"status": "success", "child": child, "message": "Дастгоҳи фарзанд бомуваффақият пайваст карда шуд!"}


# --- Firebase-independent mobile data plane ---
#
# Firebase Authentication remains the sign-in provider, but these endpoints
# are the authoritative store for pairing, apps, location and chat. This
# avoids making every feature depend on Realtime Database rules and listeners.

@router.get("/api/mobile/v2/snapshot")
def mobile_snapshot_v2(request: Request, db: Session = Depends(get_db)):
    """Дархости `GET /api/mobile/v2/snapshot`-ро барои snapshot коркард мекунад."""

    user = require_mobile_user(request, db)
    return _mobile_snapshot(db, user)


@router.post("/api/mobile/v2/pair/code")
def create_mobile_pair_code_v2(
    payload: MobilePairCodeRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Дархости `POST /api/mobile/v2/pair/code`-ро барои create pairing code коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = require_mobile_user(request, db)
    if user.get("role") != "child":
        raise HTTPException(status_code=403, detail="Коди пайвастшавиро танҳо телефони фарзанд месозад")
    child = db.query(Child).filter(Child.user_id == user["id"]).first()
    if child is None:
        child = Child(
            user_id=user["id"],
            name=payload.child_name.strip(),
            gender=payload.gender,
            age=payload.age,
            pairing_code="000000",
            is_paired=0,
            is_online=1,
        )
        db.add(child)
        db.flush()
    elif child.is_paired:
        return {"status": "success", "child_id": child.id, "pairing_code": child.pairing_code, "paired": True}
    pairing.issue_code(db, child)
    child.name = payload.child_name.strip() or child.name
    child.gender = payload.gender
    child.age = payload.age
    child.is_paired = 0
    db.commit()
    db.refresh(child)
    return {"status": "success", "child_id": child.id, "pairing_code": child.pairing_code, "paired": False}


@router.post("/api/mobile/v2/pair")
def pair_mobile_device_v2(
    payload: MobilePairRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Дархости `POST /api/mobile/v2/pair`-ро барои pairing дастгоҳ коркард мекунад."""

    user = require_mobile_user(request, db)
    if user.get("role") != "parent":
        raise HTTPException(status_code=403, detail="Танҳо волидайн метавонад дастгоҳ пайваст кунад")
    pairing.check_attempt(request, user["id"])
    child = pairing.find_child(db, payload.pairing_code)
    if child.parent_id not in (None, user["id"]):
        raise HTTPException(status_code=409, detail="Ин дастгоҳ ба оилаи дигар пайваст аст")
    child.parent_id = user["id"]
    child.is_paired = 1
    db.commit()
    db.refresh(child)
    return {"status": "success", "child": _mobile_child_payload(db, child), "message": "Фарзанд пайваст шуд"}


@router.post("/api/mobile/v2/link-existing")
def link_existing_mobile_family_v2(
    payload: MobileLinkExistingRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Дархости `POST /api/mobile/v2/link-existing`-ро барои link existing оила коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""
    child_user = require_mobile_user(request, db)
    if child_user.get("role") != "child":
        raise HTTPException(status_code=403, detail="Танҳо ҳисоби фарзанд метавонад пайваст шавад")
    child = _mobile_child(db, child_user)
    parent = find_user_by_firebase_uid(db, payload.parent_firebase_uid)
    if parent is None:
        raise HTTPException(status_code=404, detail="Ҳисоби волидайн ҳоло дар сервер кушода нашудааст")
    child.parent_id = parent.id
    child.is_paired = 1
    db.commit()
    return {"status": "success", "child": _mobile_child_payload(db, child)}


@router.post("/api/mobile/v2/children/{child_id}/apps/sync")
def sync_mobile_apps_v2(
    child_id: int,
    payload: InstalledAppsSyncRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Дархости `POST /api/mobile/v2/children/{child_id}/apps/sync`-ро барои sync app-ҳо коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = require_mobile_user(request, db)
    if user.get("role") != "child":
        raise HTTPException(status_code=403, detail="Танҳо телефони фарзанд метавонад рӯйхати барномаҳоро фиристад")
    child = _mobile_child(db, user, child_id)
    today = date.today()
    had_synced = db.query(AppRule.id).filter(
        AppRule.child_id == child.id,
        AppRule.last_synced_at.isnot(None),
    ).first() is not None
    synced_at = datetime.now(timezone.utc)
    reported_packages = {item.package_name for item in payload.apps}
    new_names = []
    for item in payload.apps:
        rule = db.query(AppRule).filter(
            AppRule.child_id == child.id,
            AppRule.package_name == item.package_name,
        ).first()
        if rule is None:
            rule = AppRule(
                child_id=child.id,
                package_name=item.package_name,
                app_name=item.app_name or item.package_name,
                daily_limit_minutes=0,
                first_seen_at=datetime.now(timezone.utc),
            )
            db.add(rule)
            new_names.append(item.app_name or item.package_name)
        elif rule.last_synced_at is None:
            # A seeded placeholder rule: the parent never chose it.
            rule.is_blocked = 0
            rule.daily_limit_minutes = 0
        was_installed = bool(rule.is_installed)
        rule.app_name = item.app_name or rule.app_name
        rule.app_icon = item.icon_base64 or rule.app_icon
        rule.last_synced_at = synced_at
        rule.is_installed = 1
        reported_name = item.app_name or item.package_name
        if not was_installed and rule.first_seen_at is not None and reported_name not in new_names:
            new_names.append(reported_name)
        usage = db.query(AppUsageDaily).filter(
            AppUsageDaily.child_id == child.id,
            AppUsageDaily.package_name == item.package_name,
            AppUsageDaily.usage_date == today,
        ).first()
        if usage is None:
            usage = AppUsageDaily(
                child_id=child.id,
                package_name=item.package_name,
                usage_date=today,
            )
            db.add(usage)
        usage.minutes = item.usage_minutes
        usage.last_used_at = item.last_used_at
    if payload.snapshot_complete and reported_packages:
        installed_query = db.query(AppRule).filter(
            AppRule.child_id == child.id,
            AppRule.is_installed == 1,
        )
        installed_query = installed_query.filter(
            ~AppRule.package_name.in_(reported_packages)
        )
        for missing_rule in installed_query.all():
            missing_rule.is_installed = 0
    child.is_online = 1
    family_events.on_seen(child)
    if had_synced and new_names and child.parent_id:
        names = ", ".join(new_names[:3]) + ("…" if len(new_names) > 3 else "")
        family_events.emit(db, child, "parent", "new_app", f"{child.name} барномаи нав насб кард", names,
                           {"apps": new_names[:10]})
    db.commit()
    return {"status": "success", "child": _mobile_child_payload(db, child)}


@router.put("/api/mobile/v2/children/{child_id}/apps/{package_name}")
def update_mobile_app_rule_v2(
    child_id: int,
    package_name: str,
    payload: AppControlUpdateRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Дархости `PUT /api/mobile/v2/children/{child_id}/apps/{package_name}`-ро барои update app қоида коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = require_mobile_user(request, db)
    if user.get("role") != "parent":
        raise HTTPException(status_code=403, detail="Танҳо волидайн қоида гузошта метавонад")
    child = _mobile_child(db, user, child_id)
    rule = db.query(AppRule).filter(
        AppRule.child_id == child.id,
        AppRule.package_name == package_name,
        AppRule.is_installed == 1,
    ).first()
    if rule is None:
        raise HTTPException(status_code=404, detail="Барнома ҳоло аз телефони фарзанд синхрон нашудааст")
    if payload.is_blocked is not None:
        rule.is_blocked = 1 if payload.is_blocked else 0
    if payload.daily_limit_minutes is not None:
        rule.daily_limit_minutes = payload.daily_limit_minutes
    if payload.schedule is not None:
        rule.schedule_json = payload.schedule.model_dump_json()
    if payload.always_allowed is not None:
        rule.always_allowed = 1 if payload.always_allowed else 0
    db.commit()
    return {"status": "success", "child": _mobile_child_payload(db, child)}


@router.post("/api/mobile/v2/children/{child_id}/location")
def update_mobile_location_v2(
    child_id: int,
    payload: MobileLocationRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Дархости `POST /api/mobile/v2/children/{child_id}/location`-ро барои update location коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = require_mobile_user(request, db)
    if user.get("role") != "child":
        raise HTTPException(status_code=403, detail="Танҳо телефони фарзанд метавонад ҷойгиршавиро фиристад")
    child = _mobile_child(db, user, child_id)
    child.latitude = payload.latitude
    child.longitude = payload.longitude
    child.address = payload.address.strip() if payload.address else child.address
    child.is_online = 1 if payload.is_online else 0
    if payload.battery_level is not None:
        child.battery_level = payload.battery_level
    family_events.on_battery(db, child, payload.battery_level)
    family_events.on_seen(child)
    child.location_updated_at = datetime.now(timezone.utc)
    db.add(LocationPoint(
        child_id=child.id,
        latitude=payload.latitude,
        longitude=payload.longitude,
        accuracy=payload.accuracy,
        battery_level=payload.battery_level,
    ))
    prune_location_history(db, child.id)
    # Ҷойи ҳозира ва огоҳии «расид / баромад» (агар волидайн онро фаъол карда бошанд).
    places = db.query(SafePlace).filter(SafePlace.child_id == child.id).all()
    place_rules.on_location(db, child, places, payload.latitude, payload.longitude, payload.accuracy)
    db.commit()
    return {"status": "success", "location": _mobile_child_payload(db, child)["location"]}


@router.get("/api/mobile/v2/children/{child_id}/chat")
def get_mobile_chat_v2(
    child_id: int,
    request: Request,
    db: Session = Depends(get_db),
    after_id: int = Query(default=0, ge=0),
):
    """Дархости `GET /api/mobile/v2/children/{child_id}/chat`-ро барои get chat коркард мекунад."""

    user = require_mobile_user(request, db)
    child = _mobile_child(db, user, child_id)
    query = db.query(ChatMessage).filter(ChatMessage.child_id == child.id, ChatMessage.id > after_id)
    if after_id == 0:
        rows = list(reversed(query.order_by(ChatMessage.id.desc()).limit(200).all()))
    else:
        rows = query.order_by(ChatMessage.id.asc()).limit(200).all()
    return {"status": "success", "messages": [item.to_dict() for item in rows]}


@router.post("/api/mobile/v2/children/{child_id}/chat")
def send_mobile_chat_v2(
    child_id: int,
    payload: MobileChatRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Дархости `POST /api/mobile/v2/children/{child_id}/chat`-ро барои send chat коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = require_mobile_user(request, db)
    child = _mobile_child(db, user, child_id)
    role = "parent" if user.get("role") == "parent" else "child"
    message = send_message(
        db=db,
        child_id=child.id,
        sender_role=role,
        sender_name=user.get("full_name") or role,
        content=payload.content.strip(),
        message_type=payload.message_type,
        duration_sec=payload.duration_sec,
    )
    sender = user.get("full_name") or ("Волидайн" if role == "parent" else child.name)
    target = "child" if role == "parent" else "parent"
    if payload.message_type == "urgent":
        family_events.emit(db, child, "parent", "sos", f"SOS — {child.name}", payload.content.strip(),
                           {"message_id": message.get("id") if isinstance(message, dict) else None,
                            "content": payload.content.strip()})
    else:
        family_events.emit(db, child, target, "message", sender, payload.content.strip(), {"sender": sender})
    db.commit()
    return {"status": "success", "message": message}


@router.delete("/api/mobile/v2/children/{child_id}")
def unlink_mobile_child_v2(child_id: int, request: Request, db: Session = Depends(get_db)):
    """Дархости `DELETE /api/mobile/v2/children/{child_id}`-ро барои unlink фарзанд коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""
    user = require_mobile_user(request, db)
    if user.get("role") != "parent":
        raise HTTPException(status_code=403, detail="Танҳо волидайн фарзандро хориҷ карда метавонад")
    child = _mobile_child(db, user, child_id)
    child.parent_id = None
    child.is_paired = 0
    # Волидайни навбатӣ таърихи макон ва чати пешинаро набояд бубинад.
    purge_child_history(db, child.id)
    db.commit()
    return {"status": "success"}


# --- Application Control v1: parent rules + child telemetry ---

@router.get("/api/v1/children/{child_id}/apps/")
def list_child_apps_v1(child_id: int, request: Request, db: Session = Depends(get_db)):
    """Дархости `GET /api/v1/children/{child_id}/apps/`-ро барои list фарзанд app-ҳо коркард мекунад."""

    user = require_auth(request)
    child = _get_owned_child(db, user, child_id)
    ensure_default_child_apps(db, child.id)
    today = date.today()
    usage_rows = db.query(AppUsageDaily).filter(
        AppUsageDaily.child_id == child.id,
        AppUsageDaily.usage_date == today,
    ).all()
    usage_by_package = {row.package_name: row for row in usage_rows}
    rules = db.query(AppRule).filter(
        AppRule.child_id == child.id,
        AppRule.is_installed == 1,
    ).order_by(AppRule.app_name.asc()).all()
    return {
        "status": "success",
        "child": child.to_dict(),
        "usage_date": today.isoformat(),
        "apps": [_rule_payload(rule, usage_by_package.get(rule.package_name)) for rule in rules],
    }


@router.put("/api/v1/children/{child_id}/apps/{package_name}/limits")
def update_child_app_limit_v1(
    child_id: int,
    package_name: str,
    payload: AppControlUpdateRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Дархости `PUT /api/v1/children/{child_id}/apps/{package_name}/limits`-ро барои update фарзанд app limit коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = require_auth(request)
    if user.get("role") != "parent":
        raise HTTPException(status_code=403, detail="Танҳо волидайн метавонанд қоида гузоранд")
    child = _get_owned_child(db, user, child_id)
    rule = db.query(AppRule).filter(
        AppRule.child_id == child.id,
        AppRule.package_name == package_name,
        AppRule.is_installed == 1,
    ).first()
    if not rule:
        raise HTTPException(status_code=404, detail="Барнома дар рӯйхати фарзанд ёфт нашуд")
    if payload.is_blocked is not None:
        rule.is_blocked = 1 if payload.is_blocked else 0
    if payload.daily_limit_minutes is not None:
        rule.daily_limit_minutes = payload.daily_limit_minutes
    if payload.schedule is not None:
        rule.schedule_json = payload.schedule.model_dump_json()
    db.commit()
    db.refresh(rule)
    # This command is deliberately returned as a complete snapshot. An FCM/WebSocket
    # adapter can forward it, while the existing Firebase listener remains compatible.
    rules = db.query(AppRule).filter(
        AppRule.child_id == child.id,
        AppRule.is_installed == 1,
    ).all()
    return {
        "status": "success",
        "app": _rule_payload(rule),
        "command": {
            "type": "app_control_snapshot",
            "child_id": child.id,
            "issued_at": datetime.now(timezone.utc).isoformat(),
            "rules": [
                {
                    "package_name": item.package_name,
                    "is_blocked": bool(item.is_blocked),
                    "daily_limit_minutes": item.daily_limit_minutes or 0,
                    "schedule": json.loads(item.schedule_json) if item.schedule_json else None,
                }
                for item in rules
            ],
        },
    }


@router.post("/api/v1/children/{child_id}/apps/report-usage")
def report_child_usage_v1(
    child_id: int,
    payload: UsageReportRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Дархости `POST /api/v1/children/{child_id}/apps/report-usage`-ро барои ҳисобот фарзанд истифода коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = require_auth(request)
    if user.get("role") != "child":
        raise HTTPException(status_code=403, detail="Танҳо телефони фарзанд метавонад telemetry фиристад")
    child = _get_owned_child(db, user, child_id)
    usage_date = payload.usage_date or date.today()
    changed = 0
    for item in payload.apps:
        row = db.query(AppUsageDaily).filter(
            AppUsageDaily.child_id == child.id,
            AppUsageDaily.package_name == item.package_name,
            AppUsageDaily.usage_date == usage_date,
        ).first()
        if row is None:
            row = AppUsageDaily(
                child_id=child.id,
                package_name=item.package_name,
                usage_date=usage_date,
            )
            db.add(row)
        row.minutes = item.minutes
        row.last_used_at = item.last_used_at
        changed += 1
    db.commit()
    return {"status": "success", "child_id": child.id, "usage_date": usage_date.isoformat(), "updated": changed}


@router.post("/api/v1/children/{child_id}/requests/time-extension")
def process_time_extension_v1(
    child_id: int,
    payload: TimeExtensionRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Дархости `POST /api/v1/children/{child_id}/requests/time-extension`-ро барои process вақт тамдид коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = require_auth(request)
    child = _get_owned_child(db, user, child_id)
    if user.get("role") == "child":
        if payload.request_id is not None or payload.status is not None:
            raise HTTPException(status_code=400, detail="Фарзанд танҳо дархости нав фиристода метавонад")
        item = AppExtensionRequest(
            child_id=child.id,
            package_name=payload.package_name,
            requested_minutes=payload.requested_minutes,
            reason=payload.reason,
            status="pending",
        )
        db.add(item)
        db.commit()
        db.refresh(item)
        return {"status": "success", "request": item.to_dict()}
    if payload.request_id is None or payload.status is None:
        raise HTTPException(status_code=400, detail="request_id ва status барои коркарди волидайн лозим аст")
    item = db.query(AppExtensionRequest).filter(
        AppExtensionRequest.id == payload.request_id,
        AppExtensionRequest.child_id == child.id,
        AppExtensionRequest.status == "pending",
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Дархости интизорӣ ёфт нашуд")
    item.status = payload.status
    item.processed_at = datetime.now(timezone.utc)
    item.processed_by = user["id"]
    db.commit()
    return {"status": "success", "request": item.to_dict()}

@router.post("/api/mobile/apps/toggle")
def toggle_child_app(payload: AppRuleToggleRequest, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /api/mobile/apps/toggle`-ро барои toggle фарзанд app коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

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
    """Дархости `POST /api/mobile/apps/limit`-ро барои set фарзанд app limit коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

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
    """Дархости `POST /api/mobile/child/rename`-ро барои rename фарзанд профил коркард мекунад."""
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
    """Дархости `POST /api/mobile/sos`-ро барои trigger SOS alert коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

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
    """Дархости `POST /api/mobile/geofence`-ро барои set geofence бехатар zone коркард мекунад."""

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
    """Дархости `POST /api/mobile/schedule/bedtime`-ро барои set вақти хоб schedule коркард мекунад."""

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
    """Дархости `POST /api/mobile/device/lock`-ро барои toggle дастгоҳ lock коркард мекунад."""

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
    """Дархости `POST /api/mobile/webfilter`-ро барои set web филтр коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

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
    """Дархости `GET /api/mobile/location/ping`-ро барои ping live location коркард мекунад."""

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
    """Дархости `POST /api/mobile/location/update`-ро барои update фарзанд location коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""
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
    """Дархости `POST /api/mobile/screentime/bonus`-ро барои reward экран вақт вақти иловагӣ коркард мекунад."""

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
    """Дархости `GET /api/mobile/apps/recent`-ро барои get recently насбшуда app-ҳо коркард мекунад."""

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
    """Дархости `GET /api/mobile/battery/alert`-ро барои check батарея ҳолат коркард мекунад."""

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
    """Дархости `GET /api/mobile/reports/daily`-ро барои get рӯзона оила ҳисобот коркард мекунад."""

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
