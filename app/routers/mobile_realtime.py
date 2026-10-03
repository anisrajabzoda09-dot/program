"""Notifications (long-poll events) and voice-call signaling for the app.

No Firebase: each phone keeps one long-poll request open to
`/api/mobile/v3/events`; the server answers as soon as something happens
(SOS, message, call…). Calls use WebRTC; offers/answers/ICE candidates are
relayed through `/api/mobile/v3/calls/...`.
"""

import os
import time
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core import events as family_events
from app.core.mobile_auth import require_mobile_user
from app.db.session import get_db
from app.models.child import Child
from app.models.family_extras import CallSession, CallSignal, FamilyEvent

router = APIRouter(prefix="/api/mobile/v3", tags=["Mobile realtime"])

RING_TIMEOUT = timedelta(seconds=45)


def _my_children(db: Session, user: dict) -> list:
    """Return every child profile accessible to the mobile family member."""

    if user.get("role") == "parent":
        return db.query(Child).filter(Child.parent_id == user["id"]).all()
    return db.query(Child).filter(Child.user_id == user["id"]).all()


def _role(user: dict) -> str:
    """Normalize the authenticated user's effective side of the family."""

    return "parent" if user.get("role") == "parent" else "child"


# ---------- Events (notifications) ----------

@router.get("/events")
def events(
    request: Request,
    db: Session = Depends(get_db),
    after_id: int = Query(default=0, ge=0),
    wait: int = Query(default=0, ge=0, le=25),
):
    """Events for this phone after `after_id`. With `wait`, hold the request
    up to that many seconds until something arrives (long-poll).
    `after_id=0` only returns the current position (no backlog flood)."""
    user = require_mobile_user(request, db)
    role = _role(user)
    deadline = time.monotonic() + wait
    while True:
        children = _my_children(db, user)
        ids = [c.id for c in children]
        if role == "parent" and children:
            family_events.check_offline(db, children)
            db.commit()
        query = db.query(FamilyEvent).filter(
            FamilyEvent.child_id.in_(ids or [-1]),
            FamilyEvent.target_role == role,
        )
        latest = query.with_entities(func.max(FamilyEvent.id)).scalar() or 0
        if after_id <= 0:
            return {"status": "success", "events": [], "latest_id": latest}
        rows = query.filter(FamilyEvent.id > after_id).order_by(FamilyEvent.id.asc()).limit(50).all()
        if rows or time.monotonic() >= deadline:
            names = {c.id: c.name for c in children}
            return {
                "status": "success",
                "events": [{**r.to_dict(), "child_name": names.get(r.child_id)} for r in rows],
                "latest_id": max([after_id] + [r.id for r in rows]),
            }
        db.expire_all()
        time.sleep(1.0)


# ---------- Calls ----------

class CallCreate(BaseModel):
    """Identify the child profile involved in a new family call."""

    child_id: int


class SignalCreate(BaseModel):
    """Validate a WebRTC offer, answer, or ICE signaling payload."""

    kind: str = Field(..., pattern="^(offer|answer|ice)$")
    payload: str = Field(..., min_length=1, max_length=20_000)


def _call(db: Session, user: dict, call_id: int) -> tuple:
    """Resolve an accessible call and expire it when ringing timed out."""

    call = db.query(CallSession).filter(CallSession.id == call_id).first()
    if call is None:
        raise HTTPException(status_code=404, detail="Занг ёфт нашуд")
    child = next((c for c in _my_children(db, user) if c.id == call.child_id), None)
    if child is None:
        raise HTTPException(status_code=404, detail="Занг ёфт нашуд")
    _expire(db, call, child)
    return call, child


def _expire(db: Session, call: CallSession, child: Child) -> None:
    """A call nobody answered within 45 s becomes «missed»."""
    if call.status != "ringing" or call.created_at is None:
        return
    created = call.created_at if call.created_at.tzinfo else call.created_at.replace(tzinfo=timezone.utc)
    if datetime.now(timezone.utc) - created > RING_TIMEOUT:
        call.status = "missed"
        call.ended_at = datetime.now(timezone.utc)
        callee = "child" if call.caller_role == "parent" else "parent"
        family_events.emit(db, child, callee, "missed_call", "Занги ҷавобнадода",
                           child.name if callee == "parent" else "Волидайн", {"call_id": call.id})
        db.commit()


@router.get("/calls/config")
def call_config(request: Request, db: Session = Depends(get_db)):
    """ICE servers for WebRTC. TURN is optional (env TURN_URLS etc.)."""
    require_mobile_user(request, db)
    servers = [{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]}]
    turn = [u.strip() for u in os.getenv("TURN_URLS", "").split(",") if u.strip()]
    if turn:
        servers.append({
            "urls": turn,
            "username": os.getenv("TURN_USERNAME", ""),
            "credential": os.getenv("TURN_PASSWORD", ""),
        })
    return {"status": "success", "ice_servers": servers}


@router.post("/calls")
def start_call(payload: CallCreate, request: Request, db: Session = Depends(get_db)):
    """Create a ringing family call and notify the other party."""

    user = require_mobile_user(request, db)
    role = _role(user)
    child = next((c for c in _my_children(db, user) if c.id == payload.child_id), None)
    if child is None or not child.is_paired:
        raise HTTPException(status_code=404, detail="Фарзанд барои занг ёфт нашуд")
    for open_call in db.query(CallSession).filter(
        CallSession.child_id == child.id, CallSession.status.in_(["ringing", "active"])
    ).all():
        _expire(db, open_call, child)
        if open_call.status in ("ringing", "active"):
            # A stale call from this side is replaced; a live call blocks.
            if open_call.status == "ringing" and open_call.caller_role == role:
                open_call.status = "ended"
                open_call.ended_at = datetime.now(timezone.utc)
            else:
                raise HTTPException(status_code=409, detail="Ҳозир занги дигар идома дорад")
    call = CallSession(child_id=child.id, caller_role=role, status="ringing")
    db.add(call)
    db.flush()
    caller_name = user.get("full_name") or ("Волидайн" if role == "parent" else child.name)
    callee = "child" if role == "parent" else "parent"
    family_events.emit(db, child, callee, "call", caller_name, "Занги овозӣ",
                       {"call_id": call.id, "caller_name": caller_name})
    db.commit()
    db.refresh(call)
    return {"status": "success", "call": call.to_dict()}


@router.get("/calls/{call_id}")
def get_call(call_id: int, request: Request, db: Session = Depends(get_db)):
    """Return the current state of an accessible family call."""

    user = require_mobile_user(request, db)
    call, _ = _call(db, user, call_id)
    return {"status": "success", "call": call.to_dict()}


def _set_status(db: Session, user: dict, call_id: int, action: str) -> dict:
    """Apply a valid accept, decline, or end transition and notify the peer."""

    call, child = _call(db, user, call_id)
    role = _role(user)
    now = datetime.now(timezone.utc)
    other = "child" if role == "parent" else "parent"
    if action == "accept":
        if call.status != "ringing" or call.caller_role == role:
            raise HTTPException(status_code=409, detail="Ин занг дигар фаъол нест")
        call.status = "active"
        call.answered_at = now
    elif action == "decline":
        if call.status != "ringing":
            raise HTTPException(status_code=409, detail="Ин занг дигар фаъол нест")
        call.status = "declined"
        call.ended_at = now
        family_events.emit(db, child, other, "call_end", "Занг рад шуд", "", {"call_id": call.id, "reason": "declined"})
    else:  # end
        if call.status in ("ringing", "active"):
            call.status = "ended"
            call.ended_at = now
            family_events.emit(db, child, other, "call_end", "Занг тамом шуд", "", {"call_id": call.id, "reason": "ended"})
    db.commit()
    return {"status": "success", "call": call.to_dict()}


@router.post("/calls/{call_id}/accept")
def accept_call(call_id: int, request: Request, db: Session = Depends(get_db)):
    """Accept an incoming ringing call for the authenticated family member."""

    return _set_status(db, require_mobile_user(request, db), call_id, "accept")


@router.post("/calls/{call_id}/decline")
def decline_call(call_id: int, request: Request, db: Session = Depends(get_db)):
    """Decline a ringing call and notify the other family member."""

    return _set_status(db, require_mobile_user(request, db), call_id, "decline")


@router.post("/calls/{call_id}/end")
def end_call(call_id: int, request: Request, db: Session = Depends(get_db)):
    """End a ringing or active call and notify the other family member."""

    return _set_status(db, require_mobile_user(request, db), call_id, "end")


@router.post("/calls/{call_id}/signal")
def send_signal(call_id: int, payload: SignalCreate, request: Request, db: Session = Depends(get_db)):
    """Persist a WebRTC signaling message for polling by the other caller."""

    user = require_mobile_user(request, db)
    call, _ = _call(db, user, call_id)
    if call.status not in ("ringing", "active"):
        raise HTTPException(status_code=409, detail="Занг тамом шудааст")
    db.add(CallSignal(call_id=call.id, from_role=_role(user), kind=payload.kind, payload=payload.payload))
    db.commit()
    return {"status": "success"}


@router.get("/calls/{call_id}/signals")
def get_signals(
    call_id: int,
    request: Request,
    db: Session = Depends(get_db),
    after_id: int = Query(default=0, ge=0),
    wait: int = Query(default=0, ge=0, le=15),
):
    """Signals from the other side (long-poll), plus the current call status."""
    user = require_mobile_user(request, db)
    role = _role(user)
    deadline = time.monotonic() + wait
    while True:
        call, _ = _call(db, user, call_id)
        rows = db.query(CallSignal).filter(
            CallSignal.call_id == call.id,
            CallSignal.from_role != role,
            CallSignal.id > after_id,
        ).order_by(CallSignal.id.asc()).limit(100).all()
        if rows or call.status not in ("ringing", "active") or time.monotonic() >= deadline:
            return {"status": "success", "call": call.to_dict(), "signals": [r.to_dict() for r in rows]}
        db.expire_all()
        time.sleep(0.5)
