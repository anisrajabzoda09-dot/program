import os

from dotenv import load_dotenv

APP_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(os.path.dirname(APP_DIR))
load_dotenv(os.path.join(PROJECT_DIR, ".env"))

class Settings:
    PROJECT_NAME: str = "Нигоҳ — Сомонаи расмии муаррифӣ ва боргирии барнома"
    PROJECT_DESCRIPTION: str = "NIGOH Family Parental Control Platform"
    APP_VERSION: str = "2.13.0"
    APP_VERSION_CODE: int = 41

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
