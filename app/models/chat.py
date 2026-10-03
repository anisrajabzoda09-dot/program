"""Файл: model-и SQLAlchemy барои маълумоти `chat` ва табдили он ба ҷавоби API."""

from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, func
from app.db.base import Base

class ChatMessage(Base):
    """Сабти `ChatMessage`-ро дар model-и SQLAlchemy муаррифӣ мекунад."""

    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id"), nullable=False, index=True)
    sender_role = Column(String, nullable=False)  # 'parent' or 'child'
    sender_name = Column(String, nullable=False)
    message_type = Column(String, default="text")  # 'text', 'voice', 'urgent'
    content = Column(String, nullable=False)
    duration_sec = Column(Integer, default=0)
    is_read = Column(Integer, default=0)
    created_at = Column(DateTime, server_default=func.now())

    def to_dict(self):
        """Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад."""

        return {
            "id": self.id,
            "child_id": self.child_id,
            "sender_role": self.sender_role,
            "sender_name": self.sender_name,
            "message_type": self.message_type,
            "content": self.content,
            "duration_sec": self.duration_sec,
            "is_read": self.is_read,
            "created_at": str(self.created_at) if self.created_at else None
        }
