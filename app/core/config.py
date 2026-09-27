import os

class Settings:
    PROJECT_NAME: str = "Нигоҳ — Сомонаи расмии муаррифӣ ва боргирии барнома"
    PROJECT_DESCRIPTION: str = "NIGOH Family Parental Control Platform"
    APP_VERSION: str = "2.9.0"
    APP_VERSION_CODE: int = 18

    BASE_DIR: str = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    STATIC_DIR: str = os.path.join(BASE_DIR, "static")
    TEMPLATES_DIR: str = os.path.join(BASE_DIR, "templates")
    DB_PATH: str = os.path.join(BASE_DIR, "nigoh.db")
    DATABASE_URL: str = f"sqlite:///{DB_PATH}"

    OFFICIAL_DOMAIN: str = "https://nigohfamily.qobus.tj"
    SESSION_COOKIE_NAME: str = "session_token"
    SESSION_MAX_AGE: int = 30 * 24 * 3600  # 30 days

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
