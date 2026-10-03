"""Файл: model-и SQLAlchemy барои маълумоти `review` ва табдили он ба ҷавоби API."""

from sqlalchemy import Column, Integer, String
from app.db.base import Base

class Review(Base):
    """Сабти `Review`-ро дар model-и SQLAlchemy муаррифӣ мекунад."""

    __tablename__ = "reviews"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    author_name = Column(String, nullable=False)
    role_title = Column(String, nullable=False)
    rating = Column(Integer, default=5)
    comment = Column(String, nullable=False)
    date = Column(String, nullable=False)

    def to_dict(self):
        """Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад."""

        return {
            "id": self.id,
            "author_name": self.author_name,
            "role_title": self.role_title,
            "rating": self.rating,
            "comment": self.comment,
            "date": self.date
        }
