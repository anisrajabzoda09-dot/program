"""Store hashed bearer sessions issued to signed-in Android devices."""

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, func
from app.db.base import Base


class MobileSession(Base):
    """Long-lived sign-in of the NIGOH Android app. Only a hash of the token is stored."""

    __tablename__ = "mobile_sessions"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    token_hash = Column(String(64), nullable=False, unique=True, index=True)
    device = Column(String(160), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    last_seen_at = Column(DateTime, server_default=func.now())
