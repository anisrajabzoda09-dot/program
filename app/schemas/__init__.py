"""Файл: schema-ҳои Pydantic барои санҷиши payload-ҳои `__init__`."""

from app.schemas.auth import UserRegister, UserLogin, GoogleAuthRequest
from app.schemas.mobile import (
    RoleSelectRequest,
    ChildCreateRequest,
    ChildProfileSetupRequest,
    PairScanRequest,
    PairRequest,
    AppRuleToggleRequest,
    AppLimitRequest,
    AdultFilterToggleRequest,
    LocationUpdateRequest,
    SendChatMessageRequest
)

__all__ = [
    "UserRegister",
    "UserLogin",
    "GoogleAuthRequest",
    "RoleSelectRequest",
    "ChildCreateRequest",
    "ChildProfileSetupRequest",
    "PairScanRequest",
    "PairRequest",
    "AppRuleToggleRequest",
    "AppLimitRequest",
    "AdultFilterToggleRequest",
    "LocationUpdateRequest",
    "SendChatMessageRequest"
]
