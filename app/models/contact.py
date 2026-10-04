"""Файл: model-и SQLAlchemy барои паёмҳое, ки аз формаи «Тамос бо мо»-и сайт меоянд."""

from sqlalchemy import Column, DateTime, Integer, String, func

from app.db.base import Base


class ContactMessage(Base):
    """Як паёми формаи тамос: кӣ навишт, мавзӯъ, матн ва ҳолати хондан."""

    __tablename__ = "contact_messages"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    name = Column(String(80), nullable=False)
    email = Column(String(120), nullable=False)
    topic = Column(String(20), nullable=False, default="question")
    message = Column(String(2000), nullable=False)
    lang = Column(String(2), nullable=False, default="tg")
    ip = Column(String(64), nullable=True)
    is_read = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, server_default=func.now(), index=True)

    def to_dict(self):
        """Сабтро ба dict барои панели админ табдил медиҳад."""
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "topic": self.topic,
            "message": self.message,
            "lang": self.lang,
            "is_read": bool(self.is_read),
            "created_at": str(self.created_at) if self.created_at else None,
        }
