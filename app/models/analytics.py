from sqlalchemy import Column, Integer, String, DateTime, func
from app.db.base import Base

class SiteAnalytics(Base):
    __tablename__ = "site_analytics"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    ip = Column(String, nullable=True, index=True)
    path = Column(String, nullable=True)
    user_agent = Column(String, nullable=True)
    event_type = Column(String, default="page_view", index=True)  # 'page_view', 'apk_download', 'qr_scan', 'auth'
    version = Column(String, default="v2.8.1")
    created_at = Column(DateTime, server_default=func.now(), index=True)

    def to_dict(self):
        return {
            "id": self.id,
            "ip": self.ip,
            "path": self.path,
            "user_agent": self.user_agent,
            "event_type": self.event_type,
            "version": self.version,
            "created_at": str(self.created_at) if self.created_at else None
        }
