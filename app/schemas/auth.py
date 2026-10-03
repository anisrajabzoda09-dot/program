"""Файл: schema-ҳои Pydantic барои санҷиши payload-ҳои `auth`."""

from pydantic import BaseModel, Field
from typing import Optional

class UserRegister(BaseModel):
    """Маълумоти `UserRegister`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    email: str = Field(..., min_length=3, description="User email address")
    password: str = Field(..., min_length=8, max_length=128, description="User password")
    full_name: str = Field(..., min_length=2, max_length=120, description="Full name")

class UserLogin(BaseModel):
    """Маълумоти `UserLogin`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    email: str = Field(..., min_length=1, description="Email or username")
    password: str = Field(..., min_length=1, max_length=128, description="Password")

class GoogleAuthRequest(BaseModel):
    """Маълумоти `GoogleAuthRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    token: str = Field(..., min_length=20, description="Google OAuth access token")
