"""Файл: schema-ҳои Pydantic барои санҷиши payload-ҳои `mobile`."""

from datetime import date, datetime
from pydantic import BaseModel, Field, field_validator
from typing import Any, Dict, List, Literal, Optional

class RoleSelectRequest(BaseModel):
    """Маълумоти `RoleSelectRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    role: str = Field(..., description="'parent' or 'child'")

class ChildCreateRequest(BaseModel):
    """Маълумоти `ChildCreateRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    name: str
    device_name: Optional[str] = "Телефони Android"

class ChildProfileSetupRequest(BaseModel):
    """Маълумоти `ChildProfileSetupRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    name: str
    gender: str = "boy"  # 'boy' or 'girl'
    age: int = 11
    device_name: Optional[str] = "Телефони Android"

class PairScanRequest(BaseModel):
    """Маълумоти `PairScanRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    pairing_code: str
    child_name: Optional[str] = None

class PairRequest(BaseModel):
    """Маълумоти `PairRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    pairing_code: str

class AppRuleToggleRequest(BaseModel):
    """Маълумоти `AppRuleToggleRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    package_name: str
    is_blocked: bool

class AppLimitRequest(BaseModel):
    """Маълумоти `AppLimitRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    package_name: str
    daily_limit_minutes: int


class AppSchedule(BaseModel):
    """Маълумоти `AppSchedule`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    enabled: bool = False
    start: str = "16:00"
    end: str = "18:00"
    weekdays: List[int] = Field(default_factory=lambda: [1, 2, 3, 4, 5])

    @field_validator("start", "end")
    @classmethod
    def validate_time(cls, value: str) -> str:
        """Барои гирифтан ё санҷидани validate вақт истифода мешавад."""

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
        """Барои гирифтан ё санҷидани validate weekdays истифода мешавад."""

        if not value or any(day not in range(1, 8) for day in value):
            raise ValueError("Рӯзҳо бояд аз 1 то 7 бошанд")
        return sorted(set(value))


class AppControlUpdateRequest(BaseModel):
    """Маълумоти `AppControlUpdateRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    is_blocked: Optional[bool] = None
    daily_limit_minutes: Optional[int] = Field(default=None, ge=0, le=1440)
    schedule: Optional[AppSchedule] = None
    always_allowed: Optional[bool] = None


class UsageReportItem(BaseModel):
    """Маълумоти `UsageReportItem`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    package_name: str = Field(..., min_length=1, max_length=255)
    minutes: int = Field(..., ge=0, le=1440)
    last_used_at: Optional[datetime] = None


class UsageReportRequest(BaseModel):
    """Маълумоти `UsageReportRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    usage_date: Optional[date] = None
    apps: List[UsageReportItem] = Field(default_factory=list)


class TimeExtensionRequest(BaseModel):
    """Маълумоти `TimeExtensionRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    request_id: Optional[int] = None
    package_name: str = Field(..., min_length=1, max_length=255)
    requested_minutes: int = Field(default=15, ge=1, le=240)
    reason: Optional[str] = Field(default=None, max_length=500)
    status: Optional[str] = Field(default=None, pattern="^(approved|rejected)$")


class AppBundleCreateRequest(BaseModel):
    """Маълумоти `AppBundleCreateRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    min_native_code: int = Field(default=24, ge=1)
    patch_type: Literal["config", "ui_schema", "assets", "full_bundle"] = "config"
    payload: Dict[str, Any] = Field(default_factory=dict)

class AdultFilterToggleRequest(BaseModel):
    """Маълумоти `AdultFilterToggleRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    block_adult_content: bool

class LocationUpdateRequest(BaseModel):
    """Маълумоти `LocationUpdateRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    address: Optional[str] = None
    battery_level: Optional[int] = Field(default=None, ge=0, le=100)
    is_online: Optional[bool] = True

class SendChatMessageRequest(BaseModel):
    """Маълумоти `SendChatMessageRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    message_type: str = "text"  # 'text', 'voice', 'urgent'
    content: str
    duration_sec: Optional[int] = 0


class InstalledAppReportItem(BaseModel):
    """Маълумоти `InstalledAppReportItem`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    package_name: str = Field(..., min_length=1, max_length=255)
    app_name: str = Field(default="", max_length=255)
    icon_base64: str = Field(default="", max_length=300_000)
    is_system_app: bool = False
    usage_minutes: int = Field(default=0, ge=0, le=1440)
    last_used_at: Optional[datetime] = None


class InstalledAppsSyncRequest(BaseModel):
    """Маълумоти `InstalledAppsSyncRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    apps: List[InstalledAppReportItem] = Field(default_factory=list)


class MobilePairCodeRequest(BaseModel):
    """Маълумоти `MobilePairCodeRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    child_name: str = Field(default="Фарзанд", min_length=1, max_length=120)
    gender: str = Field(default="boy", max_length=20)
    age: int = Field(default=11, ge=1, le=18)


class MobilePairRequest(BaseModel):
    """Маълумоти `MobilePairRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    pairing_code: str = Field(..., min_length=6, max_length=32)


class MobileLinkExistingRequest(BaseModel):
    """Маълумоти `MobileLinkExistingRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    parent_firebase_uid: str = Field(..., min_length=10, max_length=200)


class MobileLocationRequest(BaseModel):
    """Маълумоти `MobileLocationRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    accuracy: Optional[float] = Field(default=None, ge=0, le=100_000)
    speed: Optional[float] = Field(default=None, ge=0, le=1_000)
    battery_level: Optional[int] = Field(default=None, ge=0, le=100)
    address: Optional[str] = Field(default=None, max_length=500)
    is_online: bool = True


class MobileChatRequest(BaseModel):
    """Маълумоти `MobileChatRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    content: str = Field(..., min_length=1, max_length=4_000)
    message_type: str = Field(default="text", pattern="^(text|voice|urgent|call)$")
    duration_sec: int = Field(default=0, ge=0, le=3_600)
