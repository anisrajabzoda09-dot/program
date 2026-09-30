from sqlalchemy import Column, DateTime, Integer, JSON, String, func

from app.db.base import Base


class AppBundle(Base):
    """A versioned, signed-at-rest dynamic configuration patch."""

    __tablename__ = "app_bundles"

    bundle_version = Column(Integer, primary_key=True, autoincrement=True)
    min_native_code = Column(Integer, nullable=False, default=24)
    patch_type = Column(String(32), nullable=False, default="config")
    payload = Column(JSON, nullable=False, default=dict)
    checksum = Column(String(64), nullable=False, index=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    def to_dict(self) -> dict:
        return {
            "bundle_version": self.bundle_version,
            "min_native_code": self.min_native_code,
            "patch_type": self.patch_type,
            "payload": self.payload or {},
            "checksum": self.checksum,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
