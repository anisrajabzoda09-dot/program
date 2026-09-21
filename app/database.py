import sqlite3
import os
from datetime import datetime

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "nigoh.db")

def get_db():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cursor = conn.cursor()

    # Users table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT,
        full_name TEXT NOT NULL,
        role TEXT DEFAULT 'unassigned',
        google_id TEXT,
        avatar TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    # Children table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS children (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id INTEGER,
        user_id INTEGER,
        name TEXT NOT NULL,
        gender TEXT DEFAULT 'boy',
        age INTEGER DEFAULT 11,
        device_name TEXT DEFAULT 'Samsung Galaxy A54',
        pairing_code TEXT UNIQUE NOT NULL,
        is_paired INTEGER DEFAULT 0,
        is_online INTEGER DEFAULT 1,
        battery_level INTEGER DEFAULT 88,
        latitude REAL DEFAULT 38.5598,
        longitude REAL DEFAULT 68.7870,
        address TEXT DEFAULT 'ш. Душанбе, хиёбони Рӯдакӣ',
        block_adult_content INTEGER DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (parent_id) REFERENCES users(id)
    )
    """)

    # Check and add columns if upgrading existing database
    cursor.execute("PRAGMA table_info(children)")
    child_cols = [r[1] for r in cursor.fetchall()]
    if "gender" not in child_cols:
        cursor.execute("ALTER TABLE children ADD COLUMN gender TEXT DEFAULT 'boy'")
    if "age" not in child_cols:
        cursor.execute("ALTER TABLE children ADD COLUMN age INTEGER DEFAULT 11")

    # App Rules table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS app_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        child_id INTEGER NOT NULL,
        package_name TEXT NOT NULL,
        app_name TEXT NOT NULL,
        app_icon TEXT,
        category TEXT,
        is_blocked INTEGER DEFAULT 0,
        daily_limit_minutes INTEGER DEFAULT 60,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (child_id) REFERENCES children(id),
        UNIQUE(child_id, package_name)
    )
    """)

    # Family Chat & Voice Messages table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        child_id INTEGER NOT NULL,
        sender_role TEXT NOT NULL, -- 'parent' or 'child'
        sender_name TEXT NOT NULL,
        message_type TEXT DEFAULT 'text', -- 'text', 'voice', 'urgent'
        content TEXT NOT NULL, -- message text or audio base64/data
        duration_sec INTEGER DEFAULT 0,
        is_read INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (child_id) REFERENCES children(id)
    )
    """)

    # Populate sample messages if empty
    cursor.execute("SELECT COUNT(*) FROM chat_messages")
    if cursor.fetchone()[0] == 0:
        cursor.execute("""
        INSERT INTO chat_messages (child_id, sender_role, sender_name, message_type, content, duration_sec)
        VALUES 
        (1, 'parent', 'Падар', 'text', 'Салом писарам! Дарсат тамом шуд? Вақти бозиятро то соати 19:00 кушодам.', 0),
        (1, 'child', 'Алиҷон', 'voice', 'audio_voice_note_dushanbe_school_sample', 4),
        (1, 'child', 'Алиҷон', 'text', 'Салом падарҷон! Бале тамом шуд, ҳозир бо автобус ба хона меравам.', 0),
        (1, 'parent', 'Падар', 'urgent', 'Хуб, роҳро боэҳтиёт гузар ва расидан ба хона хабар деҳ.', 0)
        """)

    # Reviews table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        author_name TEXT NOT NULL,
        role_title TEXT NOT NULL,
        rating INTEGER DEFAULT 5,
        comment TEXT NOT NULL,
        date TEXT NOT NULL
    )
    """)

    # Populate default reviews if empty
    cursor.execute("SELECT COUNT(*) FROM reviews")
    if cursor.fetchone()[0] == 0:
        default_reviews = [
            ("Фарҳод Қосимов", "Падари 2 фарзанд (Душанбе)", 5, "Барномаи бисёр олиҷаноб! Писарам пештар тамоми рӯз бозиҳои телефонӣ мекард. Ҳоло вақти бозиро маҳдуд кардам ва сайтҳои хатарнокро бастам. Муҳимтар аз ҳама, бе интернет ҳам қоидаҳо кор мекунанд!", "15 Сентябр 2026"),
            ("Мадина Саидова", "Модари як писару як духтар (Хуҷанд)", 5, "Пайвастшавӣ тавассути QR-код хеле осон ва тез аст. Барои ман донистани макони фарзандонам ва муҳофизати онҳо аз сайтҳои хатарноки интернет хеле муҳим буд. Ташаккур ба созандагон!", "12 Сентябр 2026"),
            ("Рустам Назаров", "Падар (Бохтар)", 5, "Суръати кор ва интерфейси зебои тоҷикӣ маро мафтун кард. Дигар хавотир нестам, ки писарам дар мактаб телефонро барои бозӣ истифода мебарад ё не. Тавсия медиҳам!", "08 Сентябр 2026"),
            ("Шаҳноза Алиева", "Омӯзгор ва модар (Душанбе)", 5, "Дар давраи интернет барои тарбияи дурусти кӯдакон чунин барнома ҳаётан муҳим аст. Хусусан функсияи бастани барномаҳои беҳуда ва муҳофизати интернети бехатар баҳои баланд дорад.", "02 Сентябр 2026")
        ]
        cursor.executemany(
            "INSERT INTO reviews (author_name, role_title, rating, comment, date) VALUES (?, ?, ?, ?, ?)",
            default_reviews
        )

    conn.commit()
    conn.close()

# Default apps for child
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

def ensure_default_child_apps(child_id: int):
    conn = get_db()
    cursor = conn.cursor()
    for app in DEFAULT_APPS:
        cursor.execute("""
        INSERT OR IGNORE INTO app_rules (child_id, package_name, app_name, app_icon, category, is_blocked, daily_limit_minutes)
        VALUES (?, ?, ?, ?, ?, ?, 60)
        """, (child_id, app["package_name"], app["app_name"], app["app_icon"], app["category"], app["is_blocked"]))
    conn.commit()
    conn.close()

def create_or_get_child_for_user(user_id: int, name: str, gender: str = "boy", age: int = 11, role: str = "child"):
    conn = get_db()
    cursor = conn.cursor()
    import secrets
    pairing_code = f"NIGOH-{secrets.randbelow(8999)+1000}-X"
    
    if role == "child":
        cursor.execute("SELECT * FROM children WHERE user_id = ?", (user_id,))
        existing = cursor.fetchone()
        if existing:
            cursor.execute("UPDATE children SET name = ?, gender = ?, age = ? WHERE user_id = ?", (name, gender, age, user_id))
            conn.commit()
            child_id = existing["id"]
        else:
            cursor.execute("""
            INSERT INTO children (user_id, name, gender, age, pairing_code, is_paired, is_online)
            VALUES (?, ?, ?, ?, ?, 0, 1)
            """, (user_id, name, gender, age, pairing_code))
            conn.commit()
            child_id = cursor.lastrowid
    else: # parent creating a child profile
        cursor.execute("""
        INSERT INTO children (parent_id, name, gender, age, pairing_code, is_paired, is_online)
        VALUES (?, ?, ?, ?, ?, 1, 1)
        """, (user_id, name, gender, age, pairing_code))
        conn.commit()
        child_id = cursor.lastrowid

    ensure_default_child_apps(child_id)
    cursor.execute("SELECT * FROM children WHERE id = ?", (child_id,))
    res = dict(cursor.fetchone())
    conn.close()
    return res

