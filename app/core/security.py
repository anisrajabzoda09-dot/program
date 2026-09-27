import hashlib
import hmac
import secrets
import time
from typing import Optional, Dict, List
from fastapi import Request, HTTPException, status
from app.core.config import settings

# In-memory session store (token -> user dict)
SESSIONS: Dict[str, dict] = {}

class RateLimiter:
    """
    Sliding window in-memory Rate Limiter to prevent Brute-Force attacks.
    Protects against automated credential stuffing and DDoS on sensitive endpoints.
    """
    def __init__(self):
        self._history: Dict[str, List[float]] = {}

    def is_rate_limited(self, key: str, max_requests: int = 15, window_seconds: int = 60) -> bool:
        now = time.time()
        timestamps = self._history.get(key, [])
        # Filter timestamps within window
        valid_timestamps = [t for t in timestamps if now - t < window_seconds]
        if len(valid_timestamps) >= max_requests:
            self._history[key] = valid_timestamps
            return True
        valid_timestamps.append(now)
        self._history[key] = valid_timestamps
        return False

rate_limiter = RateLimiter()

def hash_password(password: str) -> str:
    """Generate SHA-256 hash of password string."""
    return hashlib.sha256(password.encode("utf-8")).hexdigest()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Timing-attack safe password verification using hmac.compare_digest."""
    candidate_hash = hash_password(plain_password)
    return hmac.compare_digest(candidate_hash, hashed_password)

def create_session(user: dict) -> str:
    """Generate a cryptographically secure 64-char hex token and store in session map."""
    token = secrets.token_hex(32)
    SESSIONS[token] = user
    return token

def get_current_user(request: Request) -> Optional[dict]:
    """Extract authenticated user from cookies or Authorization Bearer header."""
    token = request.cookies.get(settings.SESSION_COOKIE_NAME)
    if not token or token not in SESSIONS:
        auth_header = request.headers.get("Authorization")
        if auth_header and auth_header.startswith("Bearer "):
            token = auth_header.split(" ")[1]
            if token in SESSIONS:
                return SESSIONS[token]
        return None
    return SESSIONS[token]

def require_auth(request: Request) -> dict:
    """FastAPI route guard ensuring user is logged in."""
    user = get_current_user(request)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Аутентификатсия талаб карда мешавад (Authentication required)"
        )
    return user

def check_rate_limit(request: Request, action: str = "auth", max_requests: int = 20, window_seconds: int = 60):
    """Raise 429 Too Many Requests if client IP exceeds threshold."""
    forwarded = request.headers.get("X-Forwarded-For")
    ip = forwarded.split(",")[0].strip() if forwarded else (request.client.host if request.client else "127.0.0.1")
    key = f"{ip}:{action}"
    if rate_limiter.is_rate_limited(key, max_requests, window_seconds):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Шумо дархостҳои аз ҳад зиёд ирсол кардед. Лутфан пас аз 1 дақиқа дубора кӯшиш кунед."
        )
