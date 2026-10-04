"""Файл: сохтани ҷадвалҳо, migration ва ҳисоби admin."""

import os
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
from app.models.app_usage import AppUsageDaily
from app.models.extension_request import AppExtensionRequest
from app.models.app_bundle import AppBundle
from app.models.contact import ContactMessage  # noqa: F401  (create_all)
from app.models.email_code import EmailCode  # noqa: F401  (create_all)
from app.models.mobile_session import MobileSession  # noqa: F401  (create_all)
from app.models.family_extras import CallSession, CallSignal, FamilyEvent, LocationPoint, SafePlace  # noqa: F401  (create_all)
from app.crud.crud_bundle import ensure_initial_bundle
from app.core.security import hash_password

def init_db():
    """Ҷадвалҳоро месозад, migration-ро татбиқ мекунад ва admin-ро омода месозад."""
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
        user_cols = [r[1] for r in conn.execute(text("PRAGMA table_info(users)")).fetchall()]
        if "firebase_uid" not in user_cols:
            conn.execute(text("ALTER TABLE users ADD COLUMN firebase_uid TEXT"))
            conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ix_users_firebase_uid ON users (firebase_uid)"))
            conn.commit()
        if "github_id" not in user_cols:
            conn.execute(text("ALTER TABLE users ADD COLUMN github_id TEXT"))
            conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ix_users_github_id ON users (github_id)"))
            conn.commit()
        for column, ddl in (
            ("totp_secret_enc", "TEXT"),
            ("totp_enabled", "INTEGER NOT NULL DEFAULT 0"),
            ("totp_last_step", "INTEGER"),
            ("recovery_codes_json", "TEXT"),
            ("otp_failed", "INTEGER NOT NULL DEFAULT 0"),
            ("otp_locked_until", "DATETIME"),
        ):
            if column not in user_cols:
                conn.execute(text(f"ALTER TABLE users ADD COLUMN {column} {ddl}"))
                conn.commit()
        if "apple_id" not in user_cols:
            conn.execute(text("ALTER TABLE users ADD COLUMN apple_id TEXT"))
            conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ix_users_apple_id ON users (apple_id)"))
            conn.commit()
        app_rule_cols = [r[1] for r in conn.execute(text("PRAGMA table_info(app_rules)" )).fetchall()]
        if "schedule_json" not in app_rule_cols:
            conn.execute(text("ALTER TABLE app_rules ADD COLUMN schedule_json TEXT"))
            conn.commit()
        if "last_synced_at" not in app_rule_cols:
            conn.execute(text("ALTER TABLE app_rules ADD COLUMN last_synced_at DATETIME"))
            conn.commit()
        for column, ddl in (
            ("first_seen_at", "DATETIME"),
            ("always_allowed", "INTEGER DEFAULT 0"),
            ("bonus_minutes", "INTEGER DEFAULT 0"),
            ("bonus_date", "TEXT"),
        ):
            if column not in app_rule_cols:
                conn.execute(text(f"ALTER TABLE app_rules ADD COLUMN {column} {ddl}"))
                conn.commit()
        if "bedtime_json" not in cols:
            conn.execute(text("ALTER TABLE children ADD COLUMN bedtime_json TEXT"))
            conn.commit()
        for column, ddl in (
            ("study_json", "TEXT"),
            ("web_filter_json", "TEXT"),
            ("web_filter_state", "TEXT"),
            ("web_filter_reported_at", "DATETIME"),
            ("low_battery_notified", "INTEGER DEFAULT 0"),
            ("offline_notified", "INTEGER DEFAULT 0"),
        ):
            if column not in cols:
                conn.execute(text(f"ALTER TABLE children ADD COLUMN {column} {ddl}"))
                conn.commit()

    db = SessionLocal()
    try:
        # Admin account: the password comes only from the ADMIN_PASSWORD
        # environment variable (server .env), never from source code. Without
        # it the existing admin keeps its current password.
        admin_password = os.getenv("ADMIN_PASSWORD", "").strip()
        if admin_password:
            admin_email = os.getenv("ADMIN_EMAIL", "admin").strip() or "admin"
            admin_user = db.query(User).filter(User.email == admin_email).first()
            if admin_user is None:
                db.add(User(
                    email=admin_email,
                    password_hash=hash_password(admin_password),
                    full_name="Администратор",
                    role="admin",
                ))
            else:
                admin_user.password_hash = hash_password(admin_password)
                admin_user.role = "admin"
            db.commit()

        # 4. Seed the first dynamic configuration bundle. Later bundles are
        # created through the admin-only mobile bundle endpoint.
        ensure_initial_bundle(db)

    finally:
        db.close()
