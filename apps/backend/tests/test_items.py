"""Database-backed endpoint tests.

These run only when DATABASE_URL points at a live Postgres (docker-compose
provides one locally). Without it they skip, so `pytest` still passes on a
laptop with no database and in the CI lint/test job.
"""

import pytest
from httpx import AsyncClient

pytestmark = pytest.mark.database


async def test_items_roundtrip(client: AsyncClient, requires_database: str) -> None:
    created = await client.post(
        "/api/v1/items", json={"name": "widget", "description": "a test widget"}
    )
    assert created.status_code == 201
    item = created.json()
    assert item["name"] == "widget"
    assert item["id"] > 0

    listed = await client.get("/api/v1/items")
    assert listed.status_code == 200
    assert any(row["id"] == item["id"] for row in listed.json())


async def test_items_rejects_empty_name(client: AsyncClient, requires_database: str) -> None:
    response = await client.post("/api/v1/items", json={"name": ""})

    assert response.status_code == 422
