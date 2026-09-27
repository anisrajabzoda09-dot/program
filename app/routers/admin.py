from fastapi import APIRouter, Request, HTTPException, Depends
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional

from app.core.config import settings
from app.core.security import get_current_user
from app.db.session import get_db
from app.crud.crud_analytics import get_admin_dashboard_data
from app.crud.crud_child import update_child_profile, delete_child

router = APIRouter(tags=["Admin Panel"])
templates = Jinja2Templates(directory=settings.TEMPLATES_DIR)

class ChildUpdateRequest(BaseModel):
    child_id: int
    name: Optional[str] = None
    gender: Optional[str] = None
    age: Optional[int] = None
    device_name: Optional[str] = None

class ChildDeleteRequest(BaseModel):
    child_id: int

@router.get("/admin", response_class=HTMLResponse)
def admin_dashboard(request: Request, db: Session = Depends(get_db)):
    user = get_current_user(request)
    if not user or user.get("role") != "admin":
        return RedirectResponse("/auth?admin=required", status_code=303)
    stats = get_admin_dashboard_data(db)
    return templates.TemplateResponse(
        request=request,
        name="admin.html",
        context={"user": user, "stats": stats}
    )

@router.get("/api/admin/stats")
def api_admin_stats(request: Request, db: Session = Depends(get_db)):
    user = get_current_user(request)
    if not user or user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Дастрасӣ танҳо барои сармудир (Admin)")
    return get_admin_dashboard_data(db)

@router.post("/api/admin/child/update")
def api_admin_update_child(payload: ChildUpdateRequest, request: Request, db: Session = Depends(get_db)):
    """Update child name and attributes from Admin Panel."""
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
    user = get_current_user(request)
    if not user or user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Дастрасӣ танҳо барои сармудир")

    success = delete_child(db, payload.child_id)
    if not success:
        raise HTTPException(status_code=404, detail="Фарзанд ёфт нашуд")
    return {"status": "success", "message": "Дастгоҳи фарзанд нест карда шуд"}
