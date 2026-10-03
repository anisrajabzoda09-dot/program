"""Store parent testimonials displayed on the public website."""

from sqlalchemy import Column, Integer, String
from app.db.base import Base

class Review(Base):
    """Represent one rated testimonial and its public author details."""

    __tablename__ = "reviews"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    author_name = Column(String, nullable=False)
    role_title = Column(String, nullable=False)
    rating = Column(Integer, default=5)
    comment = Column(String, nullable=False)
    date = Column(String, nullable=False)

    def to_dict(self):
        """Serialize the testimonial for template and API consumption."""

        return {
            "id": self.id,
            "author_name": self.author_name,
            "role_title": self.role_title,
            "rating": self.rating,
            "comment": self.comment,
            "date": self.date
        }
