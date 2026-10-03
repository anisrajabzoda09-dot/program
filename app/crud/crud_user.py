"""Файл: амалиёти пойгоҳи додаҳо барои бахши `crud_user`."""

from typing import Optional, List
from sqlalchemy.orm import Session
from sqlalchemy import or_
from app.models.user import User
from app.core.security import hash_password
import secrets

def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """Барои гирифтан ё санҷидани get корбар by email истифода мешавад."""

    clean = email.strip()
    return db.query(User).filter(or_(User.email == clean, User.email == clean.lower())).first()

def get_user_by_id(db: Session, user_id: int) -> Optional[User]:
    """Барои гирифтан ё санҷидани get корбар by id истифода мешавад."""

    return db.query(User).filter(User.id == user_id).first()

def create_user(db: Session, email: str, password: str, full_name: str, role: str = "parent") -> User:
    """create корбар-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    pwd_hash = hash_password(password)
    new_user = User(
        email=email.strip().lower(),
        password_hash=pwd_hash,
        full_name=full_name.strip(),
        role=role
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

def update_user_role(db: Session, user_id: int, role: str) -> Optional[User]:
    """update корбар нақш-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад."""

    user = get_user_by_id(db, user_id)
    if user:
        user.role = role
        db.commit()
        db.refresh(user)
    return user

def upsert_google_user(db: Session, email: str, full_name: Optional[str], avatar: Optional[str], google_id: Optional[str]) -> User:
    """Ҳисоби Google-ро месозад ё маълумоти онро нав мекунад."""

    clean_email = email.strip().lower()
    name = full_name.strip() if full_name else clean_email.split("@")[0]
    user_avatar = avatar or "https://lh3.googleusercontent.com/a/default-user"
    gid = google_id or ("google_" + secrets.token_hex(8))

    user = get_user_by_email(db, clean_email)
    if user:
        user.avatar = user_avatar
        user.full_name = name
        if not user.google_id:
            user.google_id = gid
        db.commit()
        db.refresh(user)
        return user
    else:
        new_user = User(
            email=clean_email,
            full_name=name,
            avatar=user_avatar,
            role="parent",
            google_id=gid
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        return new_user

def get_registered_users(db: Session) -> List[dict]:
    """Барои гирифтан ё санҷидани get registered корбарон истифода мешавад."""

    users = db.query(User).filter(User.role != "admin").order_by(User.id.desc()).all()
    return [u.to_dict() for u in users]
