"""Файл: амалиёти пойгоҳи додаҳо барои бахши `crud_rules`."""

from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.app_rule import AppRule

def get_child_app_rules(db: Session, child_id: int) -> List[dict]:
    """Барои гирифтан ё санҷидани get фарзанд app қоидаҳо истифода мешавад."""

    rules = db.query(AppRule).filter(AppRule.child_id == child_id).order_by(AppRule.id.asc()).all()
    return [r.to_dict() for r in rules]

def toggle_app_rule(db: Session, child_id: int, package_name: str, is_blocked: bool) -> bool:
    """toggle app қоида-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    rule = db.query(AppRule).filter(AppRule.child_id == child_id, AppRule.package_name == package_name).first()
    if rule:
        rule.is_blocked = 1 if is_blocked else 0
        db.commit()
        return True
    return False

def set_app_rule_limit(db: Session, child_id: int, package_name: str, daily_limit_minutes: int) -> bool:
    """set app қоида limit-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    rule = db.query(AppRule).filter(AppRule.child_id == child_id, AppRule.package_name == package_name).first()
    if rule:
        rule.daily_limit_minutes = daily_limit_minutes
        db.commit()
        return True
    return False

def count_blocked_threats(db: Session) -> int:
    """Барои гирифтан ё санҷидани count blocked threats истифода мешавад."""

    return db.query(AppRule).filter(AppRule.is_blocked == 1).count()
