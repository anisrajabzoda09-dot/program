"""Файл: танзими SQLite ва session-и пойгоҳи додаҳо барои ҳар request."""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

engine = create_engine(
    settings.DATABASE_URL,
    connect_args={"check_same_thread": False},
    echo=False
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    """Барои request session-и SQLAlchemy медиҳад ва баъд онро мебандад."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
