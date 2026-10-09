"""Файл: dashboard-и admin ва API-и идоракунии фарзандон."""

import csv
from io import StringIO

from fastapi import APIRouter, Request, HTTPException, Depends, Query
from fastapi.responses import HTMLResponse, RedirectResponse, Response
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field, field_validator
from typing import Literal, Optional

from app.core.config import settings
from app.core.security import get_current_user
from app.db.session import get_db
from app.crud.crud_analytics import get_admin_dashboard_data
from app.crud.crud_child import update_child_profile, delete_child
from app.models.contact import ContactMessage
from app.models.user import User

router = APIRouter(tags=["Admin Panel"])
templates = Jinja2Templates(directory=settings.TEMPLATES_DIR)

class ChildUpdateRequest(BaseModel):
    """Маълумоти `ChildUpdateRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    child_id: int = Field(gt=0)
    name: Optional[str] = Field(default=None, min_length=1, max_length=80)
    gender: Optional[Literal["boy", "girl"]] = None
    age: Optional[int] = Field(default=None, ge=1, le=25)
    device_name: Optional[str] = Field(default=None, max_length=80)

    @field_validator("name", "device_name", mode="before")
    @classmethod
    def strip_profile_text(cls, value):
        return value.strip() if isinstance(value, str) else value

class ChildDeleteRequest(BaseModel):
    """Маълумоти `ChildDeleteRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    child_id: int = Field(gt=0)


def dashboard_days(days: int = Query(default=30)) -> int:
    if days not in (7, 14, 30, 90):
        raise HTTPException(status_code=422, detail="Давра бояд 7, 14, 30 ё 90 рӯз бошад")
    return days


def dashboard_context(db: Session, user: dict, days: int) -> dict:
    admin = db.get(User, user.get("id")) if user.get("id") else None
    rows = db.query(ContactMessage).order_by(ContactMessage.id.desc()).limit(50).all()
    return {
        "user": user,
        "stats": get_admin_dashboard_data(db, days=days),
        "messages": [row.to_dict() for row in rows],
        "unread_messages": db.query(ContactMessage).filter(ContactMessage.is_read == 0).count(),
        "totp_enabled": bool(admin and admin.totp_enabled),
    }


@router.get("/admin", response_class=HTMLResponse)
def admin_dashboard(request: Request, db: Session = Depends(get_db), days: int = Depends(dashboard_days)):
    """Дархости `GET /admin`-ро барои admin dashboard коркард мекунад."""

    user = get_current_user(request)
    if not user or user.get("role") != "admin":
        return RedirectResponse("/auth?admin=required", status_code=303)
    context = dashboard_context(db, user, days)
    response = templates.TemplateResponse(
        request=request,
        name="admin.html",
        context=context,
        headers={"Cache-Control": "no-store"},
    )
    if context["unread_messages"]:
        visible_ids = [message["id"] for message in context["messages"]]
        db.query(ContactMessage).filter(
            ContactMessage.id.in_(visible_ids), ContactMessage.is_read == 0,
        ).update({ContactMessage.is_read: 1}, synchronize_session=False)
        db.commit()
    return response

@router.get("/api/admin/stats")
def api_admin_stats(request: Request, db: Session = Depends(get_db), days: int = Depends(dashboard_days)):
    """Дархости `GET /api/admin/stats`-ро барои admin stats коркард мекунад."""

    user = get_current_user(request)
    if not user or user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Дастрасӣ танҳо барои сармудир (Admin)")
    return get_admin_dashboard_data(db, days=days)


@router.get("/api/admin/dashboard", response_class=HTMLResponse)
def api_admin_dashboard(request: Request, db: Session = Depends(get_db), days: int = Depends(dashboard_days)):
    user = get_current_user(request)
    if not user or user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Дастрасӣ танҳо барои сармудир (Admin)")
    return templates.TemplateResponse(
        request=request,
        name="_admin_content.html",
        context=dashboard_context(db, user, days),
        headers={"Cache-Control": "no-store"},
    )


@router.get("/api/admin/stats/export")
def api_admin_stats_export(request: Request, db: Session = Depends(get_db), days: int = Depends(dashboard_days)):
    user = get_current_user(request)
    if not user or user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Дастрасӣ танҳо барои сармудир (Admin)")
    stats = get_admin_dashboard_data(db, days=days)
    output = StringIO(newline="")
    columns = ("date", "timezone", "page_views", "visitors", "downloads", "direct_downloads", "qr_downloads", "registrations")
    writer = csv.DictWriter(output, fieldnames=columns, extrasaction="ignore")
    writer.writeheader()
    for row in stats["daily_chart"]:
        writer.writerow(dict(row, timezone=stats["period"]["timezone"]))
    filename = f"nigoh-statistics-{stats['period']['start_date']}-{stats['period']['end_date']}.csv"
    return Response(
        content="\ufeff" + output.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Cache-Control": "no-store",
            "X-Content-Type-Options": "nosniff",
        },
    )

@router.post("/api/admin/child/update")
def api_admin_update_child(payload: ChildUpdateRequest, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /api/admin/child/update`-ро барои admin update фарзанд коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""
    user = get_current_user(request)
    if not user or user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Дастрасӣ танҳо барои сармудир")

    updated = update_child_profile(
        db=db,
        child_id=payload.child_id,
        name=payload.name,
        gender=payload.gender,
        age=payload.age,
        device_name=payload.device_name
    )
    if not updated:
        raise HTTPException(status_code=404, detail="Фарзанд ёфт нашуд")
    return {"status": "success", "child": updated, "message": "Маълумоти фарзанд бомуваффақият иваз карда шуд"}

@router.post("/api/admin/child/delete")
def api_admin_delete_child(payload: ChildDeleteRequest, request: Request, db: Session = Depends(get_db)):
    """Дархости `POST /api/admin/child/delete`-ро барои admin delete фарзанд коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = get_current_user(request)
    if not user or user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Дастрасӣ танҳо барои сармудир")

    success = delete_child(db, payload.child_id)
    if not success:
        raise HTTPException(status_code=404, detail="Фарзанд ёфт нашуд")
    return {"status": "success", "message": "Дастгоҳи фарзанд нест карда шуд"}
