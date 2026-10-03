"""Validate browser authentication payloads for local and Google sign-in."""

from pydantic import BaseModel, Field
from typing import Optional

class UserRegister(BaseModel):
    """Require the credentials and display name for a new parent account."""

    email: str = Field(..., min_length=3, description="User email address")
    password: str = Field(..., min_length=8, max_length=128, description="User password")
    full_name: str = Field(..., min_length=2, max_length=120, description="Full name")

class UserLogin(BaseModel):
    """Require the credentials used to open a local web session."""

    email: str = Field(..., min_length=1, description="Email or username")
    password: str = Field(..., min_length=1, max_length=128, description="Password")

class GoogleAuthRequest(BaseModel):
    """Carry the Google access token exchanged for a NIGOH web session."""

    token: str = Field(..., min_length=20, description="Google OAuth access token")
