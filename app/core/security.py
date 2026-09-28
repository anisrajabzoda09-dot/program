import base64
import hashlib
import hmac
import secrets
import time
from typing import Optional, Dict, List
from fastapi import Request, HTTPException, status
from app.core.config import settings

# In-memory session store (token -> user dict)
SESSIONS: Dict[str, dict] = {}
SESSION_EXPIRY: Dict[str, float] = {}

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
    """Hash passwords with memory-hard scrypt and a per-password salt.

    The legacy SHA-256 format is still accepted by ``verify_password`` so
    existing accounts can log in once and be upgraded by the next write.
    """
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(
        password.encode("utf-8"), salt=salt, n=2**14, r=8, p=1, dklen=32
    )
    enc = base64.urlsafe_b64encode
    return "scrypt$16384$8$1${}${}".format(
        enc(salt).decode("ascii"), enc(digest).decode("ascii")
    )

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify scrypt hashes and transparently support old SHA-256 records."""
    if hashed_password.startswith("scrypt$"):
        try:
            _, n, r, p, salt_b64, digest_b64 = hashed_password.split("$", 5)
            salt = base64.urlsafe_b64decode(salt_b64.encode("ascii"))
            expected = base64.urlsafe_b64decode(digest_b64.encode("ascii"))
            actual = hashlib.scrypt(
                plain_password.encode("utf-8"),
                salt=salt,
                n=int(n),
                r=int(r),
                p=int(p),
                dklen=len(expected),
            )
            return hmac.compare_digest(actual, expected)
        except (ValueError, TypeError):
            return False
    legacy = hashlib.sha256(plain_password.encode("utf-8")).hexdigest()
    return hmac.compare_digest(legacy, hashed_password)

def create_session(user: dict) -> str:
    """Generate a cryptographically secure 64-char hex token and store in session map."""
    token = secrets.token_hex(32)
    SESSIONS[token] = dict(user)
    SESSION_EXPIRY[token] = time.time() + settings.SESSION_MAX_AGE
    return token

def get_current_user(request: Request) -> Optional[dict]:
    """Extract authenticated user from cookies or Authorization Bearer header."""
    token = request.cookies.get(settings.SESSION_COOKIE_NAME)
    if token and token in SESSION_EXPIRY and SESSION_EXPIRY[token] <= time.time():
        SESSIONS.pop(token, None)
        SESSION_EXPIRY.pop(token, None)
        token = None
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
