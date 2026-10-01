from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, func
from app.db.base import Base


class LocationPoint(Base):
    """One reported position of a child's phone (history for the parent map)."""

    __tablename__ = "location_points"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id"), nullable=False, index=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    accuracy = Column(Float, nullable=True)
    battery_level = Column(Integer, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), index=True)

    def to_dict(self):
        return {
            "latitude": self.latitude,
            "longitude": self.longitude,
            "accuracy": self.accuracy,
            "battery_level": self.battery_level,
            "created_at": str(self.created_at) if self.created_at else None,
        }


class SafePlace(Base):
    """A named circle (home, school…) the parent cares about."""

    __tablename__ = "safe_places"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id"), nullable=False, index=True)
    name = Column(String(80), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    radius_meters = Column(Integer, nullable=False, default=150)
    created_at = Column(DateTime, server_default=func.now())

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "radius_meters": self.radius_meters,
        }
