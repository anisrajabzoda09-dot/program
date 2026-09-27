from pydantic import BaseModel, Field
from typing import Optional

class RoleSelectRequest(BaseModel):
    role: str = Field(..., description="'parent' or 'child'")

class ChildCreateRequest(BaseModel):
    name: str
    device_name: Optional[str] = "Телефони Android"

class ChildProfileSetupRequest(BaseModel):
    name: str
    gender: str = "boy"  # 'boy' or 'girl'
    age: int = 11
    device_name: Optional[str] = "Телефони Android"

class PairScanRequest(BaseModel):
    pairing_code: str
    child_name: Optional[str] = None

class PairRequest(BaseModel):
    pairing_code: str

class AppRuleToggleRequest(BaseModel):
    package_name: str
    is_blocked: bool

class AppLimitRequest(BaseModel):
    package_name: str
    daily_limit_minutes: int

class AdultFilterToggleRequest(BaseModel):
    block_adult_content: bool

class LocationUpdateRequest(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    address: Optional[str] = None
    battery_level: Optional[int] = Field(default=None, ge=0, le=100)
    is_online: Optional[bool] = True

class SendChatMessageRequest(BaseModel):
    message_type: str = "text"  # 'text', 'voice', 'urgent'
    content: str
    duration_sec: Optional[int] = 0
