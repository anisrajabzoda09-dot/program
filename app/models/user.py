from sqlalchemy import Column, Integer, String, DateTime, func
from app.db.base import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    email = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=True)
    full_name = Column(String, nullable=False)
    role = Column(String, default="unassigned")
    google_id = Column(String, nullable=True)
    firebase_uid = Column(String, nullable=True, unique=True, index=True)
    avatar = Column(String, nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    def to_dict(self):
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
