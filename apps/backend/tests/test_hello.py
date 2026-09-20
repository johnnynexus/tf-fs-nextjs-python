"""Tests for the example API endpoint the frontend calls."""

import pytest
from httpx import AsyncClient

from app.core.config import Settings
from app.services.greeting import build_greeting


async def test_hello_defaults_to_world(client: AsyncClient) -> None:
    response = await client.get("/api/v1/hello")

    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "world"
    assert "Hello, world!" in body["message"]


async def test_hello_echoes_name(client: AsyncClient) -> None:
    response = await client.get("/api/v1/hello", params={"name": "Stanford"})

    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Stanford"
    assert "Hello, Stanford!" in body["message"]


async def test_hello_rejects_overlong_name(client: AsyncClient) -> None:
    response = await client.get("/api/v1/hello", params={"name": "x" * 101})

    assert response.status_code == 422


async def test_cors_preflight_allows_frontend_origin(client: AsyncClient) -> None:
    response = await client.options(
        "/api/v1/hello",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:3000"


@pytest.mark.parametrize(
    ("name", "expected"),
    [("  ", "world"), ("ada", "ada")],
)
def test_build_greeting_handles_blank_names(name: str, expected: str) -> None:
    settings = Settings(environment="local")

    assert expected in build_greeting(name, settings)
