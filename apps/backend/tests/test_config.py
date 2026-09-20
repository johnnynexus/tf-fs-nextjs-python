"""Configuration parsing tests - the bits most likely to break a deploy."""

import pytest

from app.core.config import Settings


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("http://a.com,http://b.com", ["http://a.com", "http://b.com"]),
        ("http://a.com , http://b.com ", ["http://a.com", "http://b.com"]),
        ("", []),
        ('["http://a.com"]', ["http://a.com"]),
    ],
)
def test_cors_origins_accepts_comma_separated_and_json(raw: str, expected: list[str]) -> None:
    assert Settings(cors_origins=raw).cors_origins == expected


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        (
            "postgresql://u:p@host:5432/db",
            "postgresql+asyncpg://u:p@host:5432/db",
        ),
        (
            "postgres://u:p@host:5432/db",
            "postgresql+asyncpg://u:p@host:5432/db",
        ),
        (
            "postgresql+asyncpg://u:p@host:5432/db",
            "postgresql+asyncpg://u:p@host:5432/db",
        ),
    ],
)
def test_database_url_is_normalised_to_asyncpg(raw: str, expected: str) -> None:
    settings = Settings(database_url=raw)

    assert settings.async_database_url == expected
    assert settings.database_enabled is True


def test_database_is_optional() -> None:
    settings = Settings(database_url=None)

    assert settings.database_enabled is False
    assert settings.async_database_url is None
