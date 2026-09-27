import sqlite3
from sqlalchemy import text
from app.db.base import Base
from app.db.session import engine, SessionLocal
from app.models.user import User
from app.models.child import Child
from app.models.app_rule import AppRule
from app.models.review import Review
from app.models.chat import ChatMessage
from app.models.analytics import SiteAnalytics
from app.core.security import hash_password

def init_db():
    """Initialize database tables using SQLAlchemy ORM and seed default admin/reviews."""
    Base.metadata.create_all(bind=engine)

    # Lightweight migration check for legacy sqlite columns
    with engine.connect() as conn:
        res = conn.execute(text("PRAGMA table_info(children)")).fetchall()
        cols = [r[1] for r in res]
        if "gender" not in cols:
            conn.execute(text("ALTER TABLE children ADD COLUMN gender TEXT DEFAULT 'boy'"))
            conn.commit()
        if "age" not in cols:
            conn.execute(text("ALTER TABLE children ADD COLUMN age INTEGER DEFAULT 11"))
            conn.commit()
        if "location_updated_at" not in cols:
            conn.execute(text("ALTER TABLE children ADD COLUMN location_updated_at DATETIME"))
            conn.commit()

    db = SessionLocal()
    try:
        # 1. Seed Reviews if empty
        if db.query(Review).count() == 0:
            default_reviews = [
                Review(author_name="Фарҳод Қосимов", role_title="Падари 2 фарзанд (Душанбе)", rating=5, comment="Барномаи бисёр олиҷаноб! Писарам пештар тамоми рӯз бозиҳои телефонӣ мекард. Ҳоло вақти бозиро маҳдуд кардам ва сайтҳои хатарнокро бастам. Муҳимтар аз ҳама, бе интернет ҳам қоидаҳо кор мекунанд!", date="15 Сентябр 2026"),
                Review(author_name="Мадина Саидова", role_title="Модари як писару як духтар (Хуҷанд)", rating=5, comment="Пайвастшавӣ тавассути QR-код хеле осон ва тез аст. Барои ман донистани макони фарзандонам ва муҳофизати онҳо аз сайтҳои хатарноки интернет хеле муҳим буд. Ташаккур ба созандагон!", date="12 Сентябр 2026"),
                Review(author_name="Рустам Назаров", role_title="Падар (Бохтар)", rating=5, comment="Суръати кор ва интерфейси зебои тоҷикӣ маро мафтун кард. Дигар хавотир нестам, ки писарам дар мактаб телефонро барои бозӣ истифода мебарад ё не. Тавсия медиҳам!", date="08 Сентябр 2026"),
                Review(author_name="Шаҳноза Алиева", role_title="Омӯзгор ва модар (Душанбе)", rating=5, comment="Дар давраи интернет барои тарбияи дурусти кӯдакон чунин барнома ҳаётан муҳим аст. Хусусан функсияи бастани барномаҳои беҳуда ва муҳофизати интернети бехатар баҳои баланд дорад.", date="02 Сентябр 2026")
            ]
            db.add_all(default_reviews)
            db.commit()

        # 2. Seed Admin: admin and admin@nigohfamily.tj with password 'admin321'
        admin_pwd_hash = hash_password("admin321")
        for admin_email in ["admin", "admin@nigohfamily.tj"]:
            admin_user = db.query(User).filter(User.email == admin_email).first()
            if not admin_user:
                new_admin = User(
                    email=admin_email,
                    password_hash=admin_pwd_hash,
                    full_name="Администратор (Admin)",
                    role="admin",
                    avatar="https://ui-avatars.com/api/?name=Admin&background=4f46e5&color=fff"
                )
                db.add(new_admin)
            else:
                admin_user.password_hash = admin_pwd_hash
                admin_user.role = "admin"
        db.commit()

        # 3. Seed demo devices/children if empty
        if db.query(Child).count() == 0:
            demo_children = [
                Child(name="Анушервон", gender="boy", age=12, device_name="Samsung Galaxy A54", pairing_code="NIGOH-7412-X", is_paired=1, is_online=1, battery_level=88, latitude=38.5601, longitude=68.7885, address="ш. Душанбе, хиёбони Рӯдакӣ 45"),
                Child(name="Малика", gender="girl", age=9, device_name="Xiaomi Redmi Note 12", pairing_code="NIGOH-3918-X", is_paired=1, is_online=1, battery_level=94, latitude=38.5420, longitude=68.7750, address="ш. Душанбе, кӯчаи Исмоили Сомонӣ"),
                Child(name="Беҳрӯз", gender="boy", age=14, device_name="iPhone 13 (Android Client)", pairing_code="NIGOH-8821-X", is_paired=1, is_online=0, battery_level=42, latitude=38.5710, longitude=68.8010, address="ш. Душанбе, маҳаллаи 82"),
                Child(name="Сабрина", gender="girl", age=11, device_name="Samsung Galaxy A33", pairing_code="NIGOH-1049-X", is_paired=1, is_online=1, battery_level=76, latitude=40.2850, longitude=69.6230, address="ш. Хуҷанд, маҳаллаи 19"),
                Child(name="Муҳаммадҷон", gender="boy", age=10, device_name="Honor X8b", pairing_code="NIGOH-5524-X", is_paired=1, is_online=1, battery_level=65, latitude=37.8380, longitude=68.7740, address="ш. Бохтар, кӯчаи Борбад")
            ]
            db.add_all(demo_children)
            db.commit()

    finally:
        db.close()
