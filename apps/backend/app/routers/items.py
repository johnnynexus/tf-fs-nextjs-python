"""Example database-backed resource.

These routes return 503 when the deployment has no database attached, which is
the default (`enable_database = false`). That is deliberate: the rest of the
API stays fully functional, and turning the database on is a Terraform flag
rather than a code change.
"""

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.schemas.item import ItemCreate, ItemRead
from app.services import item_service

router = APIRouter(prefix="/items", tags=["items"])


@router.get("", response_model=list[ItemRead], summary="List items")
async def list_items(session: AsyncSession = Depends(get_session)) -> list[ItemRead]:
    items = await item_service.list_items(session)
    return [ItemRead.model_validate(item) for item in items]


@router.post(
    "",
    response_model=ItemRead,
    status_code=status.HTTP_201_CREATED,
    summary="Create an item",
)
async def create_item(
    payload: ItemCreate, session: AsyncSession = Depends(get_session)
) -> ItemRead:
    item = await item_service.create_item(session, payload)
    return ItemRead.model_validate(item)
