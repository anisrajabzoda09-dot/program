"""Файл: model-и SQLAlchemy барои маълумоти `user` ва табдили он ба ҷавоби API."""

from sqlalchemy import Column, Integer, String, DateTime, func
from app.db.base import Base

class User(Base):
    """Сабти `User`-ро дар model-и SQLAlchemy муаррифӣ мекунад."""

    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    email = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=True)
    full_name = Column(String, nullable=False)
    role = Column(String, default="unassigned")
    google_id = Column(String, nullable=True)
    # Numeric GitHub account id (never changes, unlike the login name).
    github_id = Column(String, nullable=True, unique=True, index=True)
    # Stable Apple account id ("sub" claim) for Sign in with Apple.
    apple_id = Column(String, nullable=True, unique=True, index=True)
    firebase_uid = Column(String, nullable=True, unique=True, index=True)
    avatar = Column(String, nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    def to_dict(self):
        """Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад."""

        return {
            "id": self.id,
            "email": self.email,
            "full_name": self.full_name,
            "role": self.role,
            "google_id": self.google_id,
            "firebase_uid": self.firebase_uid,
            "avatar": self.avatar,
            "created_at": str(self.created_at) if self.created_at else None
        }
