"""Файл: model-и SQLAlchemy барои рамзҳои якдафъаинае, ки ба почта фиристода мешаванд."""

from sqlalchemy import Column, DateTime, Integer, String, func

from app.db.base import Base


class EmailCode(Base):
    """Як рамзи почта: ба кадом почта, барои чӣ, hash-и рамз, мӯҳлат ва кӯшишҳо."""

    __tablename__ = "email_codes"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    email = Column(String(254), nullable=False, index=True)
    purpose = Column(String(20), nullable=False, default="login")
    code_hash = Column(String(64), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    attempts = Column(Integer, nullable=False, default=0)
    used = Column(Integer, nullable=False, default=0)
    ip = Column(String(64), nullable=True)
    created_at = Column(DateTime, server_default=func.now(), index=True)
