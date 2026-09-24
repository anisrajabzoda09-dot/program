from pydantic import BaseModel
from typing import Optional, List

class UserRegister(BaseModel):
    email: str
    password: str
    full_name: str

class UserLogin(BaseModel):
    email: str
    password: str

class GoogleAuthRequest(BaseModel):
    email: str
    full_name: str
    avatar: Optional[str] = "https://lh3.googleusercontent.com/a/default-user"
    token: Optional[str] = None
    google_id: Optional[str] = None

class RoleSelectRequest(BaseModel):
    role: str # "parent" or "child"

class ChildCreateRequest(BaseModel):
    name: str
    device_name: Optional[str] = "Телефони Android"

class ChildProfileSetupRequest(BaseModel):
    name: str
    gender: str = "boy" # "boy" or "girl"
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
    latitude: float
    longitude: float
    address: Optional[str] = None
    battery_level: Optional[int] = 85
    is_online: Optional[bool] = True

class SendChatMessageRequest(BaseModel):
    message_type: str = "text" # "text", "voice", "urgent"
    content: str
    duration_sec: Optional[int] = 0
