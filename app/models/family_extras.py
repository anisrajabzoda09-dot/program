"""Файл: model-и SQLAlchemy барои маълумоти `family_extras` ва табдили он ба ҷавоби API."""

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, func
from app.db.base import Base


class LocationPoint(Base):
    """Сабти `LocationPoint`-ро дар model-и SQLAlchemy муаррифӣ мекунад."""

    __tablename__ = "location_points"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id"), nullable=False, index=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    accuracy = Column(Float, nullable=True)
    battery_level = Column(Integer, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), index=True)

    def to_dict(self):
        """Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад."""

        return {
            "latitude": self.latitude,
            "longitude": self.longitude,
            "accuracy": self.accuracy,
            "battery_level": self.battery_level,
            "created_at": str(self.created_at) if self.created_at else None,
        }


class SafePlace(Base):
    """Доираи номдори бехатарро, мисли хона ё мактаб, нигоҳ медорад."""

    __tablename__ = "safe_places"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id"), nullable=False, index=True)
    name = Column(String(80), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    radius_meters = Column(Integer, nullable=False, default=150)
    created_at = Column(DateTime, server_default=func.now())

    def to_dict(self):
        """Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад."""

        return {
            "id": self.id,
            "name": self.name,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "radius_meters": self.radius_meters,
        }


class FamilyEvent(Base):
    """Сабти `FamilyEvent`-ро дар model-и SQLAlchemy муаррифӣ мекунад."""

    __tablename__ = "family_events"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id"), nullable=False, index=True)
    target_role = Column(String(10), nullable=False, index=True)
    kind = Column(String(30), nullable=False)
    title = Column(String(160), nullable=False)
    body = Column(String(500), nullable=False, default="")
    data_json = Column(String, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), index=True)

    def to_dict(self):
        """Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад."""

        import json

        return {
            "id": self.id,
            "child_id": self.child_id,
            "kind": self.kind,
            "title": self.title,
            "body": self.body,
            "data": json.loads(self.data_json) if self.data_json else {},
            "created_at": str(self.created_at) if self.created_at else None,
        }


class CallSession(Base):
    """Сабти `CallSession`-ро дар model-и SQLAlchemy муаррифӣ мекунад."""

    __tablename__ = "call_sessions"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id"), nullable=False, index=True)
    caller_role = Column(String(10), nullable=False)
    status = Column(String(12), nullable=False, default="ringing")  # ringing|active|ended|declined|missed
    created_at = Column(DateTime, server_default=func.now())
    answered_at = Column(DateTime, nullable=True)
    ended_at = Column(DateTime, nullable=True)

    def to_dict(self):
        """Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад."""

        return {
            "id": self.id,
            "child_id": self.child_id,
            "caller_role": self.caller_role,
            "status": self.status,
            "created_at": str(self.created_at) if self.created_at else None,
            "answered_at": str(self.answered_at) if self.answered_at else None,
            "ended_at": str(self.ended_at) if self.ended_at else None,
        }


class CallSignal(Base):
    """Сабти `CallSignal`-ро дар model-и SQLAlchemy муаррифӣ мекунад."""

    __tablename__ = "call_signals"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    call_id = Column(Integer, ForeignKey("call_sessions.id"), nullable=False, index=True)
    from_role = Column(String(10), nullable=False)
    kind = Column(String(20), nullable=False)  # offer|answer|ice
    payload = Column(String, nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    def to_dict(self):
        """Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад."""

        return {"id": self.id, "from_role": self.from_role, "kind": self.kind, "payload": self.payload}
