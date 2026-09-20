"""Example ORM model, used by the `/api/v1/items` demo endpoints."""

from sqlalchemy import String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin


class Item(Base, TimestampMixin):
    __tablename__ = "items"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
