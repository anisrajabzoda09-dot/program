"""Файл: амалиёти пойгоҳи додаҳо барои бахши `crud_child`."""

import secrets
from typing import Optional, List, Dict
from sqlalchemy.orm import Session
from app.models.child import Child
from app.models.app_rule import AppRule
from app.models.chat import ChatMessage
from app.core.config import settings

def ensure_default_child_apps(db: Session, child_id: int):
    """Маълумоти ёрирасони ensure default фарзанд app-ҳо-ро омода карда, ба caller бармегардонад."""
    existing_packages = {r.package_name for r in db.query(AppRule.package_name).filter(AppRule.child_id == child_id).all()}
    new_rules = []
    for app in settings.DEFAULT_APPS:
        if app["package_name"] not in existing_packages:
            new_rules.append(AppRule(
                child_id=child_id,
                package_name=app["package_name"],
                app_name=app["app_name"],
                app_icon=app["app_icon"],
                category=app["category"],
                is_blocked=app["is_blocked"],
                daily_limit_minutes=60
            ))
    if new_rules:
        db.add_all(new_rules)
        db.commit()

def create_or_get_child_for_user(
    db: Session,
    user_id: int,
    name: str,
    gender: str = "boy",
    age: int = 11,
    role: str = "child"
) -> dict:
    """create or get фарзанд for корбар-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    pairing_code = f"NIGOH-{secrets.randbelow(8999)+1000}-X"

    if role == "child":
        child = db.query(Child).filter(Child.user_id == user_id).first()
        if child:
            child.name = name
            child.gender = gender
            child.age = age
            db.commit()
            db.refresh(child)
        else:
            child = Child(
                user_id=user_id,
                name=name,
                gender=gender,
                age=age,
                pairing_code=pairing_code,
                is_paired=0,
                is_online=1
            )
            db.add(child)
            db.commit()
            db.refresh(child)
    else:  # parent creating a child profile
        child = Child(
            parent_id=user_id,
            name=name,
            gender=gender,
            age=age,
            pairing_code=pairing_code,
            is_paired=1,
            is_online=1
        )
        db.add(child)
        db.commit()
        db.refresh(child)

    ensure_default_child_apps(db, child.id)
    return child.to_dict()

def get_child_for_user(db: Session, user_id: int, role: str) -> Optional[dict]:
    """Барои гирифтан ё санҷидани get фарзанд for корбар истифода мешавад."""

    if role == "child":
        child = db.query(Child).filter(Child.user_id == user_id).first()
    else:
        child = db.query(Child).filter(Child.parent_id == user_id).order_by(Child.id.desc()).first()
    return child.to_dict() if child else None

def get_child_by_pairing_code(db: Session, pairing_code: str) -> Optional[Child]:
    """Барои гирифтан ё санҷидани get фарзанд by pairing code истифода мешавад."""

    clean_code = pairing_code.strip().upper()
    return db.query(Child).filter(Child.pairing_code == clean_code).first()

def pair_child_with_parent(db: Session, parent_id: int, pairing_code: str) -> Optional[dict]:
    """pairing фарзанд with parent-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    child = get_child_by_pairing_code(db, pairing_code)
    if not child:
        return None
    child.parent_id = parent_id
    child.is_paired = 1
    db.commit()
    db.refresh(child)
    return child.to_dict()

def get_children_list(db: Session, limit: int = 10) -> List[dict]:
    """Барои гирифтан ё санҷидани get фарзандон list истифода мешавад."""

    children = db.query(Child).order_by(Child.id.desc()).limit(limit).all()
    return [c.to_dict() for c in children]

def update_child_profile(
    db: Session,
    child_id: int,
    name: Optional[str] = None,
    gender: Optional[str] = None,
    age: Optional[int] = None,
    device_name: Optional[str] = None
) -> Optional[dict]:
    """update фарзанд профил-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад."""
    child = db.query(Child).filter(Child.id == child_id).first()
    if not child:
        return None
    if name:
        child.name = name.strip()
    if gender:
        child.gender = gender
    if age is not None:
        child.age = age
    if device_name:
        child.device_name = device_name.strip()
    db.commit()
    db.refresh(child)
    return child.to_dict()

def delete_child(db: Session, child_id: int) -> bool:
    """delete фарзанд-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад."""
    child = db.query(Child).filter(Child.id == child_id).first()
    if not child:
        return False
    # delete rules and chat
    db.query(AppRule).filter(AppRule.child_id == child_id).delete()
    db.query(ChatMessage).filter(ChatMessage.child_id == child_id).delete()
    db.delete(child)
    db.commit()
    return True
