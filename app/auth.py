import hashlib
import secrets
import json
from typing import Optional
from fastapi import Request, HTTPException, status
from app.database import get_db

# In-memory session store (token -> user dict)
SESSIONS = {}

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()

def create_session(user: dict) -> str:
    token = secrets.token_hex(32)
    SESSIONS[token] = user
    return token

def get_current_user(request: Request) -> Optional[dict]:
    token = request.cookies.get("session_token")
    if not token or token not in SESSIONS:
        # Check authorization header
        auth_header = request.headers.get("Authorization")
        if auth_header and auth_header.startswith("Bearer "):
            token = auth_header.split(" ")[1]
            if token in SESSIONS:
                return SESSIONS[token]
        return None
    return SESSIONS[token]

def require_auth(request: Request) -> dict:
    user = get_current_user(request)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Аутентификатсия талаб карда мешавад")
    return user

