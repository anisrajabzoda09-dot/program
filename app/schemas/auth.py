from pydantic import BaseModel, Field
from typing import Optional

class UserRegister(BaseModel):
    email: str = Field(..., min_length=3, description="User email address")
    password: str = Field(..., min_length=4, description="User password")
    full_name: str = Field(..., min_length=2, description="Full name")

class UserLogin(BaseModel):
    email: str = Field(..., min_length=1, description="Email or username")
    password: str = Field(..., min_length=1, description="Password")

class GoogleAuthRequest(BaseModel):
    email: str = Field(..., min_length=3)
    full_name: Optional[str] = None
    avatar: Optional[str] = "https://lh3.googleusercontent.com/a/default-user"
    token: Optional[str] = None
    google_id: Optional[str] = None
