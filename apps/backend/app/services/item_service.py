"""Data-access logic for Items, kept out of the router."""

from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.item import Item
from app.schemas.item import ItemCreate


async def list_items(session: AsyncSession, *, limit: int = 50) -> Sequence[Item]:
    result = await session.execute(select(Item).order_by(Item.id.desc()).limit(limit))
    return result.scalars().all()


async def create_item(session: AsyncSession, payload: ItemCreate) -> Item:
    item = Item(name=payload.name, description=payload.description)
    session.add(item)
    # Flush (not commit) so the generated id and server defaults are populated;
    # the `get_session` dependency owns the commit.
    await session.flush()
    await session.refresh(item)
    return item
