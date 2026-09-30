from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, func
from app.db.base import Base


class AppExtensionRequest(Base):
    __tablename__ = "app_extension_requests"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id"), nullable=False, index=True)
    package_name = Column(String, nullable=False)
    requested_minutes = Column(Integer, nullable=False, default=15)
    reason = Column(String, nullable=True)
    status = Column(String, nullable=False, default="pending", index=True)
    created_at = Column(DateTime, server_default=func.now())
    processed_at = Column(DateTime, nullable=True)
    processed_by = Column(Integer, ForeignKey("users.id"), nullable=True)

    def to_dict(self):
        return {
            "id": self.id,
            "child_id": self.child_id,
            "package_name": self.package_name,
            "requested_minutes": self.requested_minutes,
            "reason": self.reason,
            "status": self.status,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "processed_at": self.processed_at.isoformat() if self.processed_at else None,
            "processed_by": self.processed_by,
        }
