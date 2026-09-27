from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, UniqueConstraint, func
from app.db.base import Base

class AppRule(Base):
    __tablename__ = "app_rules"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id"), nullable=False, index=True)
    package_name = Column(String, nullable=False)
    app_name = Column(String, nullable=False)
    app_icon = Column(String, nullable=True)
    category = Column(String, nullable=True)
    is_blocked = Column(Integer, default=0)
    daily_limit_minutes = Column(Integer, default=60)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        UniqueConstraint("child_id", "package_name", name="uix_child_package"),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "child_id": self.child_id,
            "package_name": self.package_name,
            "app_name": self.app_name,
            "app_icon": self.app_icon,
            "category": self.category,
            "is_blocked": self.is_blocked,
            "daily_limit_minutes": self.daily_limit_minutes,
            "updated_at": str(self.updated_at) if self.updated_at else None
        }
