"""The endpoint the frontend calls to prove end-to-end connectivity."""

from fastapi import APIRouter, Query

from app.core.config import settings
from app.schemas.common import HelloResponse
from app.services.greeting import build_greeting

router = APIRouter(tags=["hello"])


@router.get("/hello", response_model=HelloResponse, summary="Example greeting")
async def hello(
    name: str = Query(
        default="world",
        max_length=100,
        description="Name to greet; defaults to 'world'.",
    ),
) -> HelloResponse:
    return HelloResponse(
        message=build_greeting(name, settings),
        environment=settings.environment,
        name=name.strip() or "world",
    )
