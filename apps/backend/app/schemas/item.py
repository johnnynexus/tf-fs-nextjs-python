"""Request/response schemas for the example Item resource."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ItemCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=5000)


class ItemRead(BaseModel):
    # from_attributes lets FastAPI serialise SQLAlchemy ORM objects directly.
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str | None
    created_at: datetime
    updated_at: datetime
