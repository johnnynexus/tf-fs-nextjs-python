"""Shared pytest fixtures.

The HTTP client talks to the ASGI app in-process via httpx's ASGITransport -
no network, no running server, so the suite is fast and works in CI without
any services.
"""

import os
from collections.abc import AsyncGenerator

import pytest
from httpx import ASGITransport, AsyncClient

# Force a known configuration before `app` is imported, since settings are
# read at import time.
os.environ.setdefault("ENVIRONMENT", "local")
os.environ.setdefault("RELEASE", "test")
os.environ.setdefault("CORS_ORIGINS", "http://localhost:3000")


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """An HTTP client bound to the app, with lifespan events executed."""
    from app.main import app

    # Run startup/shutdown so the database (if configured) is initialised the
    # same way it is in production.
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as http_client:
        async with app.router.lifespan_context(app):
            yield http_client


@pytest.fixture
def database_url() -> str | None:
    return os.environ.get("DATABASE_URL")


@pytest.fixture
def requires_database(database_url: str | None) -> str:
    if not database_url:
        pytest.skip("DATABASE_URL is not set; skipping database-backed test")
    return database_url
