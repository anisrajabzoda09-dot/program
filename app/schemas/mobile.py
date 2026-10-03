"""Define and validate payloads used by legacy and current mobile APIs."""

from datetime import date, datetime
from pydantic import BaseModel, Field, field_validator
from typing import Any, Dict, List, Literal, Optional

class RoleSelectRequest(BaseModel):
    """Carry the family role selected for the current device."""

    role: str = Field(..., description="'parent' or 'child'")

class ChildCreateRequest(BaseModel):
    """Describe the minimal child profile a parent can create."""

    name: str
    device_name: Optional[str] = "Телефони Android"

class ChildProfileSetupRequest(BaseModel):
    """Validate child identity and device details during initial setup."""

    name: str
    gender: str = "boy"  # 'boy' or 'girl'
    age: int = 11
    device_name: Optional[str] = "Телефони Android"

class PairScanRequest(BaseModel):
    """Carry a scanned pairing code and an optional child label."""

    pairing_code: str
    child_name: Optional[str] = None

class PairRequest(BaseModel):
    """Carry the child-device code used for family pairing."""

    pairing_code: str

class AppRuleToggleRequest(BaseModel):
    """Identify an app and its requested blocked state."""

    package_name: str
    is_blocked: bool

class AppLimitRequest(BaseModel):
    """Identify an app and its requested daily allowance in minutes."""

    package_name: str
    daily_limit_minutes: int


class AppSchedule(BaseModel):
    """Validate a recurring time window and its enabled weekdays."""

    enabled: bool = False
    start: str = "16:00"
    end: str = "18:00"
    weekdays: List[int] = Field(default_factory=lambda: [1, 2, 3, 4, 5])

    @field_validator("start", "end")
    @classmethod
    def validate_time(cls, value: str) -> str:
        """Normalize valid 24-hour times to zero-padded HH:MM form."""

        parts = value.strip().split(":")
        if len(parts) != 2:
            raise ValueError("Вақт бояд дар формати HH:MM бошад")
        hour, minute = (int(part) for part in parts)
        if hour not in range(24) or minute not in range(60):
            raise ValueError("Вақт бояд дар формати HH:MM бошад")
        return f"{hour:02d}:{minute:02d}"

    @field_validator("weekdays")
    @classmethod
    def validate_weekdays(cls, value: List[int]) -> List[int]:
        """Reject invalid days and return a sorted unique weekday list."""

        if not value or any(day not in range(1, 8) for day in value):
            raise ValueError("Рӯзҳо бояд аз 1 то 7 бошанд")
        return sorted(set(value))


class AppControlUpdateRequest(BaseModel):
    """Collect optional blocking, limit, schedule, and exemption changes."""

    is_blocked: Optional[bool] = None
    daily_limit_minutes: Optional[int] = Field(default=None, ge=0, le=1440)
    schedule: Optional[AppSchedule] = None
    always_allowed: Optional[bool] = None


class UsageReportItem(BaseModel):
    """Validate one app's daily usage total and last-use time."""

    package_name: str = Field(..., min_length=1, max_length=255)
    minutes: int = Field(..., ge=0, le=1440)
    last_used_at: Optional[datetime] = None


class UsageReportRequest(BaseModel):
    """Group application usage readings for one reporting date."""

    usage_date: Optional[date] = None
    apps: List[UsageReportItem] = Field(default_factory=list)


class TimeExtensionRequest(BaseModel):
    """Describe a child's extra-time request or a parent's decision on it."""

    request_id: Optional[int] = None
    package_name: str = Field(..., min_length=1, max_length=255)
    requested_minutes: int = Field(default=15, ge=1, le=240)
    reason: Optional[str] = Field(default=None, max_length=500)
    status: Optional[str] = Field(default=None, pattern="^(approved|rejected)$")


class AppBundleCreateRequest(BaseModel):
    """Validate an admin-supplied dynamic mobile configuration patch."""

    min_native_code: int = Field(default=24, ge=1)
    patch_type: Literal["config", "ui_schema", "assets", "full_bundle"] = "config"
    payload: Dict[str, Any] = Field(default_factory=dict)

class AdultFilterToggleRequest(BaseModel):
    """Carry the requested adult-content filtering state for a child."""

    block_adult_content: bool

class LocationUpdateRequest(BaseModel):
    """Validate a legacy child location, battery, and connectivity report."""

    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    address: Optional[str] = None
    battery_level: Optional[int] = Field(default=None, ge=0, le=100)
    is_online: Optional[bool] = True

class SendChatMessageRequest(BaseModel):
    """Describe a legacy family chat message or voice-message duration."""

    message_type: str = "text"  # 'text', 'voice', 'urgent'
    content: str
    duration_sec: Optional[int] = 0


class InstalledAppReportItem(BaseModel):
    """Validate one installed app and optional usage metadata from a phone."""

    package_name: str = Field(..., min_length=1, max_length=255)
    app_name: str = Field(default="", max_length=255)
    icon_base64: str = Field(default="", max_length=300_000)
    is_system_app: bool = False
    usage_minutes: int = Field(default=0, ge=0, le=1440)
    last_used_at: Optional[datetime] = None


class InstalledAppsSyncRequest(BaseModel):
    """Group the complete installed-app inventory reported by a child phone."""

    apps: List[InstalledAppReportItem] = Field(default_factory=list)


class MobilePairCodeRequest(BaseModel):
    """Validate child details used when generating a mobile pairing code."""

    child_name: str = Field(default="Фарзанд", min_length=1, max_length=120)
    gender: str = Field(default="boy", max_length=20)
    age: int = Field(default=11, ge=1, le=18)


class MobilePairRequest(BaseModel):
    """Validate the code a parent submits to pair a child device."""

    pairing_code: str = Field(..., min_length=6, max_length=32)


class MobileLinkExistingRequest(BaseModel):
    """Identify an existing parent account for legacy Firebase linking."""

    parent_firebase_uid: str = Field(..., min_length=10, max_length=200)


class MobileLocationRequest(BaseModel):
    """Validate a current location, accuracy, speed, battery, and online report."""

    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    accuracy: Optional[float] = Field(default=None, ge=0, le=100_000)
    speed: Optional[float] = Field(default=None, ge=0, le=1_000)
    battery_level: Optional[int] = Field(default=None, ge=0, le=100)
    address: Optional[str] = Field(default=None, max_length=500)
    is_online: bool = True


class MobileChatRequest(BaseModel):
    """Validate a current text, voice, urgent, or call chat message."""

    content: str = Field(..., min_length=1, max_length=4_000)
    message_type: str = Field(default="text", pattern="^(text|voice|urgent|call)$")
    duration_sec: int = Field(default=0, ge=0, le=3_600)
