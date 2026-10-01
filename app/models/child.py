from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, func
from app.db.base import Base

class Child(Base):
    __tablename__ = "children"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    parent_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    user_id = Column(Integer, nullable=True, index=True)
    name = Column(String, nullable=False)
    gender = Column(String, default="boy")
    age = Column(Integer, default=11)
    device_name = Column(String, default="Samsung Galaxy A54")
    pairing_code = Column(String, unique=True, nullable=False, index=True)
    is_paired = Column(Integer, default=0)
    is_online = Column(Integer, default=1)
    battery_level = Column(Integer, default=88)
    latitude = Column(Float, default=38.5598)
    longitude = Column(Float, default=68.7870)
    address = Column(String, default="ш. Душанбе, хиёбони Рӯдакӣ")
    location_updated_at = Column(DateTime, nullable=True)
    bedtime_json = Column(String, nullable=True)
    study_json = Column(String, nullable=True)
    low_battery_notified = Column(Integer, default=0)
    offline_notified = Column(Integer, default=0)
    block_adult_content = Column(Integer, default=1)
    created_at = Column(DateTime, server_default=func.now())

    def to_dict(self):
        return {
            "id": self.id,
            "parent_id": self.parent_id,
            "user_id": self.user_id,
            "name": self.name,
            "gender": self.gender,
            "age": self.age,
            "device_name": self.device_name,
            "pairing_code": self.pairing_code,
            "is_paired": self.is_paired,
            "is_online": self.is_online,
            "battery_level": self.battery_level,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "address": self.address,
            "location_updated_at": str(self.location_updated_at) if self.location_updated_at else None,
            "block_adult_content": self.block_adult_content,
            "created_at": str(self.created_at) if self.created_at else None
        }
