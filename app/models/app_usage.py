"""Файл: model-и SQLAlchemy барои маълумоти `app_usage` ва табдили он ба ҷавоби API."""

from sqlalchemy import Column, Date, DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from app.db.base import Base


class AppUsageDaily(Base):
    """Сабти `AppUsageDaily`-ро дар model-и SQLAlchemy муаррифӣ мекунад."""

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
        """Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад."""

        return {
            "id": self.id,
            "child_id": self.child_id,
            "package_name": self.package_name,
            "usage_date": self.usage_date.isoformat(),
            "minutes": self.minutes,
            "last_used_at": self.last_used_at.isoformat() if self.last_used_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
