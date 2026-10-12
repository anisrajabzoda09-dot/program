"""Файл: history, дархости вақт, bonus, bedtime ва safe place-ҳои оила."""

import json
from datetime import date, datetime, timedelta, timezone
from typing import List, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field, ValidationError, model_validator
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core import events as family_events
from app.core import gemini_ai, place_rules, web_filter
from app.core.mobile_auth import require_mobile_user
from app.core.security import check_rate_limit
from app.db.session import get_db
from app.models.app_rule import AppRule
from app.models.app_usage import AppUsageDaily
from app.models.chat import ChatMessage
from app.models.child import Child
from app.models.extension_request import AppExtensionRequest
from app.models.family_extras import LocationPoint, SafePlace

router = APIRouter(prefix="/api/mobile/v2/children/{child_id}", tags=["Mobile family"])

_TIME = r"^([01]\d|2[0-3]):[0-5]\d$"


def _child(db: Session, user: dict, child_id: int) -> Child:
    """Маълумоти ёрирасони фарзанд-ро омода карда, ба caller бармегардонад."""

    query = db.query(Child).filter(Child.id == child_id)
    if user.get("role") == "parent":
        query = query.filter(Child.parent_id == user["id"])
    else:
        query = query.filter(Child.user_id == user["id"])
    child = query.first()
    if child is None:
        raise HTTPException(status_code=404, detail="Фарзанд барои ин ҳисоб ёфт нашуд")
    return child


def _parent_only(user: dict) -> None:
    """Маълумоти ёрирасони parent only-ро омода карда, ба caller бармегардонад."""

    if user.get("role") != "parent":
        raise HTTPException(status_code=403, detail="Танҳо волидайн ин амалро карда метавонад")


def _child_only(user: dict) -> None:
    """Маълумоти ёрирасони фарзанд only-ро омода карда, ба caller бармегардонад."""

    if user.get("role") != "child":
        raise HTTPException(status_code=403, detail="Танҳо телефони фарзанд ин амалро карда метавонад")


def _add_bonus(rule: AppRule, minutes: int) -> None:
    """Маълумоти ёрирасони add вақти иловагӣ-ро омода карда, ба caller бармегардонад."""

    today = date.today().isoformat()
    current = rule.bonus_minutes if rule.bonus_date == today else 0
    rule.bonus_minutes = min(720, (current or 0) + minutes)
    rule.bonus_date = today


class AiSchedule(BaseModel):
    """Ҷадвали пешниҳодшудаи AI, ки пеш аз намоиш дубора санҷида мешавад."""

    enabled: bool = True
    start: str = Field(pattern=_TIME)
    end: str = Field(pattern=_TIME)
    weekdays: list[int] = Field(default_factory=lambda: [1, 2, 3, 4, 5], min_length=1, max_length=7)

    @model_validator(mode="after")
    def valid_days(self):
        if any(day < 1 or day > 7 for day in self.weekdays):
            raise ValueError("weekday must be 1..7")
        self.weekdays = sorted(set(self.weekdays))
        return self


class AiRuleAction(BaseModel):
    """Як тағйири пешниҳодшуда барои барномаи воқеан насбшуда."""

    package_name: str = Field(min_length=1, max_length=200)
    is_blocked: Optional[bool] = None
    daily_limit_minutes: Optional[int] = Field(default=None, ge=0, le=720)
    schedule: Optional[AiSchedule] = None
    reason: str = Field(default="", max_length=240)

    @model_validator(mode="after")
    def has_change(self):
        if self.is_blocked is None and self.daily_limit_minutes is None and self.schedule is None:
            raise ValueError("action must change at least one setting")
        return self


class AiRuleProposal(BaseModel):
    """Пешниҳоди сохтории AI; танҳо preview аст ва худкор татбиқ намешавад."""

    summary: str = Field(min_length=1, max_length=500)
    actions: list[AiRuleAction] = Field(default_factory=list, max_length=50)


class AiInstruction(BaseModel):
    instruction: str = Field(min_length=5, max_length=1000)


class AiHelpRequest(BaseModel):
    question: str = Field(min_length=3, max_length=800)


class AiCategoryAction(BaseModel):
    package_name: str = Field(min_length=1, max_length=200)
    category: Literal["games", "social", "education", "video", "other"]


class AiCategoriesApply(BaseModel):
    categories: list[AiCategoryAction] = Field(default_factory=list, max_length=100)


_AI_PROPOSAL_SCHEMA = {
    "type": "object",
    "properties": {
        "summary": {"type": "string"},
        "actions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "package_name": {"type": "string"},
                    "is_blocked": {"type": "boolean"},
                    "daily_limit_minutes": {"type": "integer", "minimum": 0, "maximum": 720},
                    "schedule": {
                        "type": "object",
                        "properties": {
                            "enabled": {"type": "boolean"},
                            "start": {"type": "string"},
                            "end": {"type": "string"},
                            "weekdays": {"type": "array", "items": {"type": "integer"}},
                        },
                        "required": ["enabled", "start", "end", "weekdays"],
                    },
                    "reason": {"type": "string"},
                },
                "required": ["package_name", "reason"],
            },
        },
    },
    "required": ["summary", "actions"],
}


def _ai_call(prompt: str, schema: dict) -> dict:
    try:
        return gemini_ai.generate_json(prompt, schema)
    except gemini_ai.GeminiUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.post("/ai/rules/preview")
def preview_ai_rules(child_id: int, payload: AiInstruction, request: Request, db: Session = Depends(get_db)):
    """Аз забони оддӣ preview-и қоида месозад; ягон тағйиротро татбиқ намекунад."""

    check_rate_limit(request, "gemini_rules", max_requests=12, window_seconds=3600)
    user = require_mobile_user(request, db)
    _parent_only(user)
    child = _child(db, user, child_id)
    apps = db.query(AppRule).filter(AppRule.child_id == child.id, AppRule.is_installed == 1).all()
    if not apps:
        raise HTTPException(status_code=400, detail="Рӯйхати барномаҳо ҳоло холӣ аст")
    catalog = [
        {
            "package_name": app.package_name,
            "app_name": app.app_name,
            "category": app.category or "unknown",
            "blocked": bool(app.is_blocked),
            "limit_minutes": app.daily_limit_minutes or 0,
        }
        for app in apps
    ]
    prompt = (
        "You are NIGOH Family's parental-control rule planner. Return JSON only in the requested schema. "
        "Never add packages outside the catalog. Do not block dialer, phone, SMS, settings, system UI, "
        "or this parental-control app. Use 0 for no daily limit. Explain briefly in Tajik. "
        f"Child age: {child.age}. Parent instruction: {payload.instruction.strip()}\n"
        f"Installed app catalog: {json.dumps(catalog, ensure_ascii=False)}"
    )
    raw = _ai_call(prompt, _AI_PROPOSAL_SCHEMA)
    try:
        proposal = AiRuleProposal.model_validate(raw)
    except ValidationError as exc:
        raise HTTPException(status_code=502, detail="AI пешниҳоди нодуруст баргардонд") from exc
    by_package = {app.package_name: app for app in apps}
    safe_actions = []
    protected_tokens = ("dialer", "telecom", "phone", "messaging", "settings", "systemui", "nigoh")
    for action in proposal.actions:
        app = by_package.get(action.package_name)
        if app is None:
            continue
        if action.is_blocked and any(token in action.package_name.lower() for token in protected_tokens):
            action.is_blocked = False
        safe_actions.append(action)
    proposal.actions = safe_actions
    return {"status": "success", "proposal": proposal.model_dump(), "applied": False}


@router.post("/ai/weekly-summary")
def ai_weekly_summary(child_id: int, request: Request, db: Session = Depends(get_db)):
    """Аз омори ҷамъшудаи 7 рӯз хулосаи кӯтоҳ месозад, бе ном ва макони фарзанд."""

    check_rate_limit(request, "gemini_summary", max_requests=12, window_seconds=3600)
    user = require_mobile_user(request, db)
    _parent_only(user)
    child = _child(db, user, child_id)
    start = date.today() - timedelta(days=6)
    rows = db.query(AppUsageDaily).filter(
        AppUsageDaily.child_id == child.id, AppUsageDaily.usage_date >= start
    ).all()
    names = dict(db.query(AppRule.package_name, AppRule.app_name).filter(AppRule.child_id == child.id).all())
    data = [
        {"date": row.usage_date.isoformat(), "app": names.get(row.package_name, "App"), "minutes": row.minutes or 0}
        for row in rows if (row.minutes or 0) > 0
    ]
    schema = {
        "type": "object",
        "properties": {
            "summary": {"type": "string"},
            "tips": {"type": "array", "items": {"type": "string"}},
        },
        "required": ["summary", "tips"],
    }
    raw = _ai_call(
        "Summarize this 7-day child screen-time aggregate in Tajik. Be supportive, not diagnostic; "
        "give at most 3 concrete tips. No names or assumptions. Data: " + json.dumps(data, ensure_ascii=False),
        schema,
    )
    summary = str(raw.get("summary", "")).strip()[:1200]
    tips = [str(item).strip()[:300] for item in raw.get("tips", []) if str(item).strip()][:3]
    if not summary:
        raise HTTPException(status_code=502, detail="AI хулосаи дуруст барнагардонд")
    return {"status": "success", "summary": summary, "tips": tips}


@router.post("/ai/help")
def ai_help(child_id: int, payload: AiHelpRequest, request: Request, db: Session = Depends(get_db)):
    """Ёвари кӯтоҳи NIGOH бе фиристодани маълумоти шахсии фарзанд."""

    check_rate_limit(request, "gemini_help", max_requests=20, window_seconds=3600)
    user = require_mobile_user(request, db)
    _parent_only(user)
    _child(db, user, child_id)
    schema = {"type": "object", "properties": {"answer": {"type": "string"}}, "required": ["answer"]}
    raw = _ai_call(
        "Answer in Tajik as NIGOH Family help. Explain only parental-control settings, safe places, "
        "screen-time limits, web filter, and permissions. Never claim you changed settings. Question: "
        + payload.question.strip(),
        schema,
    )
    answer = str(raw.get("answer", "")).strip()[:1600]
    if not answer:
        raise HTTPException(status_code=502, detail="AI ҷавоби дуруст барнагардонд")
    return {"status": "success", "answer": answer}


@router.post("/ai/categories/preview")
def preview_ai_categories(child_id: int, request: Request, db: Session = Depends(get_db)):
    """Категорияҳои барномаҳоро пешниҳод мекунад, вале то тасдиқ база тағйир намеёбад."""

    check_rate_limit(request, "gemini_categories", max_requests=8, window_seconds=3600)
    user = require_mobile_user(request, db)
    _parent_only(user)
    child = _child(db, user, child_id)
    apps = db.query(AppRule).filter(
        AppRule.child_id == child.id,
        AppRule.is_installed == 1,
    ).order_by(AppRule.app_name.asc()).limit(100).all()
    catalog = [{"package_name": app.package_name, "app_name": app.app_name} for app in apps]
    schema = {
        "type": "object",
        "properties": {
            "categories": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "package_name": {"type": "string"},
                        "category": {
                            "type": "string",
                            "enum": ["games", "social", "education", "video", "other"],
                        },
                    },
                    "required": ["package_name", "category"],
                },
            },
        },
        "required": ["categories"],
    }
    raw = _ai_call(
        "Classify every installed Android app into exactly one category: games, social, education, "
        "video, or other. Return JSON only. Catalog: " + json.dumps(catalog, ensure_ascii=False),
        schema,
    )
    installed = {app.package_name for app in apps}
    clean = []
    for item in raw.get("categories", [])[:100]:
        try:
            value = AiCategoryAction.model_validate(item)
        except ValidationError:
            continue
        if value.package_name in installed:
            clean.append(value.model_dump())
    return {"status": "success", "categories": clean, "applied": False}


@router.post("/ai/categories/apply")
def apply_ai_categories(
    child_id: int,
    payload: AiCategoriesApply,
    request: Request,
    db: Session = Depends(get_db),
):
    """Танҳо категорияҳои аз ҷониби волидайн тасдиқшударо нигоҳ медорад."""

    user = require_mobile_user(request, db)
    _parent_only(user)
    child = _child(db, user, child_id)
    by_package = {
        app.package_name: app
        for app in db.query(AppRule).filter(
            AppRule.child_id == child.id,
            AppRule.is_installed == 1,
        ).all()
    }
    updated = 0
    for item in payload.categories:
        app = by_package.get(item.package_name)
        if app is None:
            continue
        app.category = item.category
        updated += 1
    db.commit()
    return {"status": "success", "updated": updated}


# ---------- Location history ----------

@router.get("/locations")
def location_history(
    child_id: int,
    request: Request,
    db: Session = Depends(get_db),
    hours: int = Query(default=24, ge=1, le=168),
):
    """Дархости `GET /locations`-ро барои location таърих коркард мекунад."""

    user = require_mobile_user(request, db)
    child = _child(db, user, child_id)
    since = datetime.now(timezone.utc) - timedelta(hours=hours)
    rows = db.query(LocationPoint).filter(
        LocationPoint.child_id == child.id,
        LocationPoint.created_at >= since.replace(tzinfo=None),
    ).order_by(LocationPoint.id.asc()).limit(1000).all()
    return {"status": "success", "points": [r.to_dict() for r in rows]}


# ---------- Screen time history ----------

@router.get("/usage")
def usage_history(
    child_id: int,
    request: Request,
    db: Session = Depends(get_db),
    days: int = Query(default=7, ge=1, le=31),
):
    """Дархости `GET /usage`-ро барои истифода таърих коркард мекунад."""

    user = require_mobile_user(request, db)
    child = _child(db, user, child_id)
    start = date.today() - timedelta(days=days - 1)
    names = dict(db.query(AppRule.package_name, AppRule.app_name).filter(AppRule.child_id == child.id).all())
    rows = db.query(AppUsageDaily).filter(
        AppUsageDaily.child_id == child.id,
        AppUsageDaily.usage_date >= start,
    ).all()
    per_day: dict = {}
    for row in rows:
        per_day.setdefault(row.usage_date, []).append(row)
    result = []
    for offset in range(days):
        day = start + timedelta(days=offset)
        items = sorted(per_day.get(day, []), key=lambda r: r.minutes or 0, reverse=True)
        result.append({
            "date": day.isoformat(),
            "minutes": sum(r.minutes or 0 for r in items),
            "top": [
                {"package_name": r.package_name, "app_name": names.get(r.package_name, r.package_name), "minutes": r.minutes or 0}
                for r in items[:5] if (r.minutes or 0) > 0
            ],
        })
    return {"status": "success", "days": result}


# ---------- Extra-time requests ----------

class TimeRequestCreate(BaseModel):
    """Маълумоти `TimeRequestCreate`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    package_name: str = Field(..., min_length=1, max_length=255)
    minutes: int = Field(default=15, ge=5, le=120)
    reason: Optional[str] = Field(default=None, max_length=300)


class TimeRequestDecision(BaseModel):
    """Маълумоти `TimeRequestDecision`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    approve: bool
    minutes: Optional[int] = Field(default=None, ge=5, le=240)


def _request_payload(db: Session, row: AppExtensionRequest) -> dict:
    """Маълумоти ёрирасони дархост payload-ро омода карда, ба caller бармегардонад."""

    rule = db.query(AppRule).filter(AppRule.child_id == row.child_id, AppRule.package_name == row.package_name).first()
    return {**row.to_dict(), "app_name": rule.app_name if rule else row.package_name}


@router.post("/requests")
def create_time_request(child_id: int, payload: TimeRequestCreate, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /requests`-ро барои create вақт дархост коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад ва notification мефиристад."""

    user = require_mobile_user(request, db)
    _child_only(user)
    child = _child(db, user, child_id)
    pending = db.query(AppExtensionRequest).filter(
        AppExtensionRequest.child_id == child.id,
        AppExtensionRequest.package_name == payload.package_name,
        AppExtensionRequest.status == "pending",
    ).first()
    if pending:
        raise HTTPException(status_code=409, detail="Дархост аллакай фиристода шудааст. Ҷавоби волидайнро интизор шавед")
    row = AppExtensionRequest(
        child_id=child.id,
        package_name=payload.package_name,
        requested_minutes=payload.minutes,
        reason=(payload.reason or "").strip() or None,
        status="pending",
    )
    db.add(row)
    rule = db.query(AppRule).filter(AppRule.child_id == child.id, AppRule.package_name == payload.package_name).first()
    app_name = rule.app_name if rule else payload.package_name
    family_events.emit(db, child, "parent", "time_request", f"{child.name}: +{payload.minutes} дақ барои {app_name}",
                       row.reason or "Фарзанд вақти иловагӣ мепурсад.",
                       {"package_name": payload.package_name, "app_name": app_name,
                        "minutes": payload.minutes, "reason": row.reason})
    db.commit()
    db.refresh(row)
    return {"status": "success", "request": _request_payload(db, row)}


@router.get("/requests")
def list_time_requests(
    child_id: int,
    request: Request,
    db: Session = Depends(get_db),
    status: str = Query(default="all", pattern="^(all|pending)$"),
):
    """Дархости `GET /requests`-ро барои list вақт дархостҳо коркард мекунад."""

    user = require_mobile_user(request, db)
    child = _child(db, user, child_id)
    query = db.query(AppExtensionRequest).filter(AppExtensionRequest.child_id == child.id)
    if status == "pending":
        query = query.filter(AppExtensionRequest.status == "pending")
    rows = query.order_by(AppExtensionRequest.id.desc()).limit(50).all()
    return {"status": "success", "requests": [_request_payload(db, r) for r in rows]}


@router.post("/requests/{request_id}/decision")
def decide_time_request(
    child_id: int,
    request_id: int,
    payload: TimeRequestDecision,
    request: Request,
    db: Session = Depends(get_db),
):
    """Дархости `POST /requests/{request_id}/decision`-ро барои decide вақт дархост коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад ва notification мефиристад."""

    user = require_mobile_user(request, db)
    _parent_only(user)
    child = _child(db, user, child_id)
    row = db.query(AppExtensionRequest).filter(
        AppExtensionRequest.id == request_id,
        AppExtensionRequest.child_id == child.id,
    ).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Дархост ёфт нашуд")
    if row.status != "pending":
        raise HTTPException(status_code=409, detail="Ба ин дархост аллакай ҷавоб дода шудааст")
    row.status = "approved" if payload.approve else "denied"
    row.processed_at = datetime.now(timezone.utc)
    row.processed_by = user["id"]
    if payload.approve:
        rule = db.query(AppRule).filter(AppRule.child_id == child.id, AppRule.package_name == row.package_name).first()
        if rule is None:
            raise HTTPException(status_code=404, detail="Барнома ёфт нашуд")
        _add_bonus(rule, payload.minutes or row.requested_minutes)
    rule_name = _request_payload(db, row)["app_name"]
    family_events.emit(
        db, child, "child", "time_decision",
        "Иҷозат дода шуд" if payload.approve else "Дархост рад шуд",
        f"{rule_name}: +{payload.minutes or row.requested_minutes} дақ" if payload.approve else rule_name,
        {"approved": payload.approve, "app_name": rule_name,
         "minutes": (payload.minutes or row.requested_minutes) if payload.approve else 0},
    )
    db.commit()
    return {"status": "success", "request": _request_payload(db, row)}


# ---------- Bonus time ----------

class BonusRequest(BaseModel):
    """Маълумоти `BonusRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    minutes: int = Field(..., ge=5, le=240)


@router.post("/apps/{package_name}/bonus")
def give_bonus(child_id: int, package_name: str, payload: BonusRequest, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /apps/{package_name}/bonus`-ро барои give вақти иловагӣ коркард мекунад."""

    user = require_mobile_user(request, db)
    _parent_only(user)
    child = _child(db, user, child_id)
    rule = db.query(AppRule).filter(AppRule.child_id == child.id, AppRule.package_name == package_name).first()
    if rule is None:
        raise HTTPException(status_code=404, detail="Барнома ёфт нашуд")
    _add_bonus(rule, payload.minutes)
    db.commit()
    return {"status": "success", "bonus_minutes_today": rule.bonus_minutes}


# ---------- Bedtime ----------

class Bedtime(BaseModel):
    """Маълумоти `Bedtime`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    enabled: bool = False
    start: str = Field(default="21:30", pattern=_TIME)
    end: str = Field(default="07:00", pattern=_TIME)


class StudyMode(BaseModel):
    """Маълумоти `StudyMode`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    enabled: bool = False
    start: str = Field(default="08:00", pattern=_TIME)
    end: str = Field(default="13:00", pattern=_TIME)
    weekdays: list = Field(default_factory=lambda: [1, 2, 3, 4, 5, 6])


class WebFilterSettings(BaseModel):
    """Танзими филтри сайтҳо: сатҳи синну сол ва сайтҳое, ки волидайн дастӣ бастанд."""

    level: Literal["off", "kids", "teen"] = "off"
    blocked: List[str] = Field(default_factory=list, max_length=200)


class ChildSettings(BaseModel):
    """Маълумоти `ChildSettings`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    bedtime: Optional[Bedtime] = None
    study: Optional[StudyMode] = None
    web_filter: Optional[WebFilterSettings] = None


@router.put("/settings")
def update_child_settings(child_id: int, payload: ChildSettings, request: Request, db: Session = Depends(get_db)):
    """Дархости `PUT /settings`-ро барои update фарзанд танзимот коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = require_mobile_user(request, db)
    _parent_only(user)
    child = _child(db, user, child_id)
    if payload.study is not None:
        days = sorted({int(d) for d in payload.study.weekdays if 1 <= int(d) <= 7})
        payload.study.weekdays = days
        child.study_json = payload.study.model_dump_json()
    if payload.bedtime is not None:
        child.bedtime_json = payload.bedtime.model_dump_json()
    if payload.web_filter is not None:
        web_filter.save(child, payload.web_filter.level, payload.web_filter.blocked)
    db.commit()
    return {
        "status": "success",
        "bedtime": json.loads(child.bedtime_json) if child.bedtime_json else None,
        "study": json.loads(child.study_json) if child.study_json else None,
        "web_filter": web_filter.payload(child),
    }


class WebFilterState(BaseModel):
    """Ҳолати филтри сайтҳо, ки телефони фарзанд хабар медиҳад."""

    state: Literal["active", "off", "needs_permission", "unsupported"]


@router.post("/web-filter/state")
def report_web_filter_state(child_id: int, payload: WebFilterState, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /web-filter/state`: телефони фарзанд мегӯяд, ки филтр фаъол аст ё не."""

    user = require_mobile_user(request, db)
    _child_only(user)
    child = _child(db, user, child_id)
    web_filter.report_state(db, child, payload.state)
    db.commit()
    return {"status": "success", "web_filter": web_filter.payload(child)}


class ProtectionState(BaseModel):
    """Ҳолати иҷозатҳо ва хидматҳои муҳофизат дар телефони фарзанд."""

    usage: bool = False
    overlay: bool = False
    accessibility: bool = False
    deviceAdmin: bool = False
    location: bool = False
    backgroundLocation: bool = False
    gps: bool = False
    notifications: bool = False
    androidVersion: Optional[str] = Field(default=None, max_length=40)
    manufacturer: Optional[str] = Field(default=None, max_length=80)
    sdk: Optional[int] = Field(default=None, ge=1, le=1000)
    appVersion: Optional[str] = Field(default=None, max_length=40)
    versionCode: Optional[int] = Field(default=None, ge=1)


@router.post("/protection")
def report_protection(child_id: int, payload: ProtectionState, request: Request, db: Session = Depends(get_db)):
    """Телефони фарзанд ҳолати воқеии муҳофизатро хабар медиҳад."""

    user = require_mobile_user(request, db)
    _child_only(user)
    child = _child(db, user, child_id)
    previous = json.loads(child.protection_json) if child.protection_json else {}
    state = payload.model_dump(exclude_none=True)
    child.protection_json = json.dumps(state, ensure_ascii=False)
    child.protection_reported_at = datetime.now(timezone.utc)
    critical = ("usage", "overlay", "accessibility", "location", "notifications")
    missing = [key for key in critical if not state.get(key, False)]
    previously_missing = [key for key in critical if previous and not previous.get(key, False)]
    if missing and (not previous or set(missing) != set(previously_missing)):
        family_events.emit(
            db,
            child,
            "parent",
            "protection_off",
            f"Муҳофизати {child.name} пурра фаъол нест",
            f"{len(missing)} иҷозати муҳим хомӯш аст.",
            {"missing": missing},
        )
    db.commit()
    return {"status": "success", "protection": state}


# ---------- Safe places ----------

class SafePlaceCreate(BaseModel):
    """Маълумоти `SafePlaceCreate`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    name: str = Field(..., min_length=1, max_length=80)
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    radius_meters: int = Field(default=100, ge=50, le=2000)


@router.get("/places")
def list_places(child_id: int, request: Request, db: Session = Depends(get_db)):
    """Дархости `GET /places`-ро барои list маконҳо коркард мекунад."""

    user = require_mobile_user(request, db)
    child = _child(db, user, child_id)
    rows = db.query(SafePlace).filter(SafePlace.child_id == child.id).order_by(SafePlace.id.asc()).all()
    return {"status": "success", "places": [r.to_dict() for r in rows]}


@router.post("/places")
def add_place(child_id: int, payload: SafePlaceCreate, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /places`-ро барои add макон коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = require_mobile_user(request, db)
    _parent_only(user)
    child = _child(db, user, child_id)
    if db.query(func.count(SafePlace.id)).filter(SafePlace.child_id == child.id).scalar() >= 10:
        raise HTTPException(status_code=400, detail="Ҳадди аксар 10 ҷой")
    row = SafePlace(child_id=child.id, **payload.model_dump())
    row.name = row.name.strip()
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"status": "success", "place": row.to_dict()}


class PlaceAppRule(BaseModel):
    """Қоидаи як барнома дар ҷой: баста, бо лимит ё ҳамеша кушода."""

    mode: Literal["block", "limit", "allow"]
    minutes: Optional[int] = Field(default=None, ge=5, le=720)


class PlaceRules(BaseModel):
    """Қоидаҳои ҷой: барномаҳо ва огоҳии омадан/рафтан."""

    apps: dict[str, PlaceAppRule] = Field(default_factory=dict, max_length=300)
    notify: bool = False
    alert_child: bool = False
    vibrate_child: bool = False


class SafePlaceUpdate(BaseModel):
    """Тағйири ҷой: ном, радиус ва/ё қоидаҳо (майдонҳои холӣ иваз намешаванд)."""

    name: Optional[str] = Field(default=None, min_length=1, max_length=80)
    radius_meters: Optional[int] = Field(default=None, ge=50, le=2000)
    rules: Optional[PlaceRules] = None


@router.put("/places/{place_id}")
def update_place(child_id: int, place_id: int, payload: SafePlaceUpdate, request: Request, db: Session = Depends(get_db)):
    """Дархости `PUT /places/{place_id}`: ном, радиус ва қоидаҳои барномаҳоро дар ин ҷой иваз мекунад."""

    user = require_mobile_user(request, db)
    _parent_only(user)
    child = _child(db, user, child_id)
    row = db.query(SafePlace).filter(SafePlace.id == place_id, SafePlace.child_id == child.id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Ҷой ёфт нашуд")
    if payload.name is not None:
        row.name = payload.name.strip() or row.name
    if payload.radius_meters is not None:
        row.radius_meters = payload.radius_meters
    if payload.rules is not None:
        rules = place_rules.normalize_rules(payload.rules.model_dump())
        row.rules_json = json.dumps(rules, ensure_ascii=False)
    db.commit()
    db.refresh(row)
    return {"status": "success", "place": row.to_dict()}


@router.delete("/places/{place_id}")
def delete_place(child_id: int, place_id: int, request: Request, db: Session = Depends(get_db)):
    """Дархости `DELETE /places/{place_id}`-ро барои delete макон коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = require_mobile_user(request, db)
    _parent_only(user)
    child = _child(db, user, child_id)
    deleted = db.query(SafePlace).filter(SafePlace.id == place_id, SafePlace.child_id == child.id).delete()
    db.commit()
    if not deleted:
        raise HTTPException(status_code=404, detail="Ҷой ёфт нашуд")
    return {"status": "success"}


# ---------- Read receipts ----------

@router.post("/chat/read")
def mark_chat_read(child_id: int, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /chat/read`-ро барои mark chat read коркард мекунад."""
    user = require_mobile_user(request, db)
    child = _child(db, user, child_id)
    other = "child" if user.get("role") == "parent" else "parent"
    updated = db.query(ChatMessage).filter(
        ChatMessage.child_id == child.id,
        ChatMessage.sender_role == other,
        ChatMessage.is_read == 0,
    ).update({ChatMessage.is_read: 1})
    db.commit()
    return {"status": "success", "marked": updated}
