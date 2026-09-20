"""Health endpoint tests."""

from httpx import AsyncClient


async def test_health_returns_ok(client: AsyncClient) -> None:
    response = await client.get("/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["environment"] == "local"
    assert body["release"] == "test"


async def test_readiness_reports_database_state(client: AsyncClient) -> None:
    response = await client.get("/health/ready")

    assert response.status_code == 200
    body = response.json()
    # With no DATABASE_URL the database is "disabled", not an error, and the
    # service is still considered ready.
    assert body["database"] in {"ok", "disabled"}
    assert body["status"] == "ok"
