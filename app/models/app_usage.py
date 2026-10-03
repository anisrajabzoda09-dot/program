"""Store per-day app usage totals reported by child devices."""

from sqlalchemy import Column, Date, DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from app.db.base import Base


class AppUsageDaily(Base):
    """Represent a child's accumulated minutes for one app and calendar day."""

    __tablename__ = "app_usage_daily"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id"), nullable=False, index=True)
    package_name = Column(String, nullable=False, index=True)
    usage_date = Column(Date, nullable=False, index=True)
    minutes = Column(Integer, nullable=False, default=0)
    last_used_at = Column(DateTime, nullable=True)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        UniqueConstraint("child_id", "package_name", "usage_date", name="uix_usage_child_package_date"),
    )

    def to_dict(self):
        """Serialize a daily usage record with ISO-formatted timestamps."""

        return {
            "id": self.id,
            "child_id": self.child_id,
            "package_name": self.package_name,
            "usage_date": self.usage_date.isoformat(),
            "minutes": self.minutes,
            "last_used_at": self.last_used_at.isoformat() if self.last_used_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
