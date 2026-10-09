"""Файл: танзимоти server, роҳҳо, credential-ҳо ва қиматҳои пешфарз."""

import os

from dotenv import load_dotenv

APP_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(os.path.dirname(APP_DIR))
load_dotenv(os.path.join(PROJECT_DIR, ".env"))

class Settings:
    """Маълумоти `Settings`-ро барои санҷиш ва коркарди request нигоҳ медорад."""

    PROJECT_NAME: str = "Нигоҳ — Сомонаи расмии муаррифӣ ва боргирии барнома"
    PROJECT_DESCRIPTION: str = "NIGOH Family Parental Control Platform"
    APP_VERSION: str = "2.22.0"
    APP_VERSION_CODE: int = 50
    # Санаи охирини навсозии матни сайт (барои <lastmod> дар sitemap.xml).
    SITE_UPDATED: str = "2026-10-09"

    BASE_DIR: str = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    STATIC_DIR: str = os.path.join(BASE_DIR, "static")
    TEMPLATES_DIR: str = os.path.join(BASE_DIR, "templates")
    DB_PATH: str = os.path.join(BASE_DIR, "nigoh.db")
    DATABASE_URL: str = f"sqlite:///{DB_PATH}"

    OFFICIAL_DOMAIN: str = "https://nigohfamily.qobus.tj"
    SESSION_COOKIE_NAME: str = "session_token"
    SESSION_MAX_AGE: int = 30 * 24 * 3600  # 30 days

    GOOGLE_CLIENT_ID: str = os.getenv("GOOGLE_CLIENT_ID", "")
    GOOGLE_CLIENT_SECRET: str = os.getenv("GOOGLE_CLIENT_SECRET", "")
    GOOGLE_REDIRECT_URI: str = os.getenv(
        "GOOGLE_REDIRECT_URI",
        f"{OFFICIAL_DOMAIN}/auth/google/callback",
    )
    GOOGLE_AUTHORIZATION_ENDPOINT: str = "https://accounts.google.com/o/oauth2/v2/auth"
    GOOGLE_TOKEN_ENDPOINT: str = "https://oauth2.googleapis.com/token"
    GOOGLE_USERINFO_ENDPOINT: str = "https://openidconnect.googleapis.com/v1/userinfo"
    GOOGLE_OAUTH_SCOPES: str = "openid email profile"
    GOOGLE_OAUTH_STATE_MAX_AGE: int = 10 * 60

    # This is the public Firebase Web API key from google-services.json. It is
    # used only to validate Firebase ID tokens through Google's Identity
    # Toolkit endpoint; no Firebase database write is performed by the API.
    # OAuth client IDs whose Google ID tokens the Android app may send
    # (web client used as serverClientId, plus the Android client).
    # Sign in with GitHub (empty = the GitHub button is hidden and the routes refuse).
    # One OAuth App serves both the website and the phone app; its
    # "Authorization callback URL" must be GITHUB_REDIRECT_URI.
    GITHUB_CLIENT_ID: str = os.getenv("GITHUB_CLIENT_ID", "")
    GITHUB_CLIENT_SECRET: str = os.getenv("GITHUB_CLIENT_SECRET", "")
    GITHUB_REDIRECT_URI: str = os.getenv(
        "GITHUB_REDIRECT_URI", "https://nigohfamily.qobus.tj/auth/github/callback"
    )
    GITHUB_APP_SCHEME: str = os.getenv("GITHUB_APP_SCHEME", "nigohfamily")
    GITHUB_AUTHORIZATION_ENDPOINT: str = "https://github.com/login/oauth/authorize"
    GITHUB_TOKEN_ENDPOINT: str = "https://github.com/login/oauth/access_token"
    GITHUB_API: str = "https://api.github.com"
    GITHUB_TICKET_MAX_AGE: int = 120

    # Ҳимояи дуқабата (OTP). OTP_ENCRYPTION_KEY — калиди Fernet барои рамзгузории калидҳои
    # Authenticator дар база; бе он TOTP хомӯш аст. Рамз ба почта танҳо бо SMTP кор мекунад.
    OTP_ENCRYPTION_KEY: str = os.getenv("OTP_ENCRYPTION_KEY", "")
    OTP_ISSUER: str = os.getenv("OTP_ISSUER", "NIGOH Family")
    OTP_MAX_ATTEMPTS: int = 5            # кӯшишҳои нодуруст то қулф
    OTP_LOCK_MINUTES: int = 15           # мӯҳлати қулф
    OTP_TICKET_SECONDS: int = 300        # вақт барои ворид кардани рамз пас аз парол
    EMAIL_CODE_TTL_SECONDS: int = 600    # рамзи почта 10 дақиқа эътибор дорад
    EMAIL_CODE_PER_HOUR: int = 3         # ҳадди аксар рамзҳо ба як почта дар як соат
    EMAIL_CODE_COOLDOWN_SECONDS: int = 60
    SMTP_HOST: str = os.getenv("SMTP_HOST", "")
    SMTP_PORT: int = int(os.getenv("SMTP_PORT", "587") or 587)
    SMTP_USER: str = os.getenv("SMTP_USER", "")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD", "")
    SMTP_FROM: str = os.getenv("SMTP_FROM", "")
    SMTP_SSL: bool = os.getenv("SMTP_SSL", "").lower() in ("1", "true", "yes")

    # Sign in with Apple (all empty = the Apple button is hidden and the routes refuse).
    # APPLE_CLIENT_ID is the Services ID; the private key is the .p8 key text
    # (newlines may be written as \n) or a path in APPLE_PRIVATE_KEY_PATH.
    APPLE_CLIENT_ID: str = os.getenv("APPLE_CLIENT_ID", "")
    APPLE_TEAM_ID: str = os.getenv("APPLE_TEAM_ID", "")
    APPLE_KEY_ID: str = os.getenv("APPLE_KEY_ID", "")
    APPLE_PRIVATE_KEY: str = os.getenv("APPLE_PRIVATE_KEY", "").replace("\\n", "\n")
    APPLE_PRIVATE_KEY_PATH: str = os.getenv("APPLE_PRIVATE_KEY_PATH", "")
    APPLE_REDIRECT_URI: str = os.getenv(
        "APPLE_REDIRECT_URI", "https://nigohfamily.qobus.tj/auth/apple/callback"
    )
    # Extra audiences accepted from the phone app (comma-separated; the
    # Services ID is always accepted).
    APPLE_MOBILE_CLIENT_IDS: str = os.getenv("APPLE_MOBILE_CLIENT_IDS", "")
    APPLE_ANDROID_PACKAGE: str = os.getenv("APPLE_ANDROID_PACKAGE", "tj.nigoh.nigoh_family_parent")
    APPLE_ISSUER: str = "https://appleid.apple.com"
    APPLE_AUTHORIZATION_ENDPOINT: str = "https://appleid.apple.com/auth/authorize"
    APPLE_TOKEN_ENDPOINT: str = "https://appleid.apple.com/auth/token"
    APPLE_KEYS_ENDPOINT: str = "https://appleid.apple.com/auth/keys"

    GOOGLE_MOBILE_CLIENT_IDS: str = os.getenv(
        "GOOGLE_MOBILE_CLIENT_IDS",
        "708817646656-mdjfklgfsfaq83h9q5fa0j1mr74avo03.apps.googleusercontent.com,"
        "708817646656-g5854pqbq7oiitabo57538t5eiak8gqj.apps.googleusercontent.com",
    )
    FIREBASE_PROJECT_ID: str = os.getenv("FIREBASE_PROJECT_ID", "nigoh-family")
    FIREBASE_WEB_API_KEY: str = os.getenv(
        "FIREBASE_WEB_API_KEY", "AIzaSyAJyW9g2_r_arrDz9jpuemJVu6ZYzD50ao"
    )

    DEFAULT_APPS = [
        {"package_name": "com.zhiliaoapp.musically", "app_name": "TikTok", "app_icon": "🎵", "category": "Шабакаҳои иҷтимоӣ", "is_blocked": 1},
        {"package_name": "com.instagram.android", "app_name": "Instagram", "app_icon": "📸", "category": "Шабакаҳои иҷтимоӣ", "is_blocked": 1},
        {"package_name": "com.dts.freefireth", "app_name": "Free Fire", "app_icon": "🔥", "category": "Бозиҳо", "is_blocked": 1},
        {"package_name": "com.tencent.ig", "app_name": "PUBG Mobile", "app_icon": "🔫", "category": "Бозиҳо", "is_blocked": 1},
        {"package_name": "com.roblox.client", "app_name": "Roblox", "app_icon": "🧱", "category": "Бозиҳо", "is_blocked": 1},
        {"package_name": "com.google.android.youtube", "app_name": "YouTube", "app_icon": "▶️", "category": "Видео", "is_blocked": 0},
        {"package_name": "org.telegram.messenger", "app_name": "Telegram", "app_icon": "✈️", "category": "Муошират", "is_blocked": 0},
        {"package_name": "com.whatsapp", "app_name": "WhatsApp", "app_icon": "💬", "category": "Муошират", "is_blocked": 0},
        {"package_name": "org.khanacademy.android", "app_name": "Khan Academy", "app_icon": "📚", "category": "Таҳсил", "is_blocked": 0},
        {"package_name": "com.duolingo", "app_name": "Duolingo", "app_icon": "🦉", "category": "Таҳсил", "is_blocked": 0}
    ]

    APK_CANDIDATES = [
        "NIGOH_Family_Android_v2.22.0.apk",
        "NIGOH_Family_Android_v2.21.0.apk",
        "NIGOH_Family_Android_v2.20.0.apk",
        "NIGOH_Family_Android_v2.19.0.apk",
        "NIGOH_Family_Android_v2.18.0.apk",
        "NIGOH_Family_Android_v2.17.0.apk",
        "NIGOH_Family_Android_v2.15.0.apk",
        "NIGOH_Family_Android_v2.14.0.apk",
        "NIGOH_Family_Android_v2.13.0.apk",
        "NIGOH_Family_Android_v2.12.0.apk",
        "NIGOH_Family_Android_v2.11.0.apk",
        "NIGOH_Family_Android_v2.10.0.apk",
        "NIGOH_Family_Android_v2.9.19.apk",
        "NIGOH_Family_Android_v2.9.18.apk",
        "NIGOH_Family_Android_v2.9.17.apk",
        "NIGOH_Family_Android_v2.9.15.apk",
        "NIGOH_Family_Android_v2.9.13.apk",
        "NIGOH_Family_Android_v2.9.12.apk",
        "NIGOH_Family_Android_v2.9.11.apk",
        "NIGOH_Family_Android_v2.9.10.apk",
        "Nigoh_Family_v2.0.0.apk",
        "NIGOH_Family_Android_v2.9.1.apk",
        "NIGOH_Family_Android_v2.9.1_full_glass.apk",
        "NIGOH_Family_Android_v2.9.0.apk",
        "NIGOH_Family_Android_v2.8.1.apk",
        "NIGOH_Family_Android_v2.8.0.apk",
        "NIGOH_Family_Android_v2.7.0.apk",
        "NIGOH_Family_Android_v2.6.3.apk",
        "NIGOH_Family_Android_v2.6.2.apk",
        "NIGOH_Family_Android_v2.6.1.apk",
        "NIGOH_Family_Android_v2.6.0.apk",
        "NIGOH_Family_Android_v2.5.0.apk"
    ]

settings = Settings()
