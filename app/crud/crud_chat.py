"""Файл: амалиёти пойгоҳи додаҳо барои бахши `crud_chat`."""

from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.chat import ChatMessage

def get_child_messages(db: Session, child_id: int, limit: int = 50) -> List[dict]:
    """Барои гирифтан ё санҷидани get фарзанд паёмҳо истифода мешавад."""
    msgs = db.query(ChatMessage).filter(ChatMessage.child_id == child_id).order_by(ChatMessage.id.asc()).limit(limit).all()
    return [m.to_dict() for m in msgs]

def send_message(
    db: Session,
    child_id: int,
    sender_role: str,
    sender_name: str,
    content: str,
    message_type: str = "text",
    duration_sec: int = 0
) -> dict:
    """send паём-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад."""
    msg = ChatMessage(
        child_id=child_id,
        sender_role=sender_role,
        sender_name=sender_name,
        message_type=message_type,
        content=content,
        duration_sec=duration_sec
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)
    return msg.to_dict()
