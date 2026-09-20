"""Async database engine and session management.

The database is optional. When `DATABASE_URL` is unset the engine is never
created, `get_session` raises a clean 503, and the readiness probe reports the
database as "disabled" rather than failing. This is what lets the service be
deployed with `enable_database = false` in Terraform while the same code runs
against Postgres locally via docker-compose.
"""

from __future__ import annotations

import logging
from collections.abc import AsyncGenerator

from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import Settings, settings
from app.db.base import Base

logger = logging.getLogger(__name__)

# Module-level singletons. Created in `init_db` during app startup and torn
# down in `close_db`, so the engine's connection pool lives exactly as long as
# the process does.
_engine: AsyncEngine | None = None
_session_factory: async_sessionmaker[AsyncSession] | None = None


def get_engine() -> AsyncEngine | None:
    return _engine


async def init_db(config: Settings = settings, *, create_tables: bool = True) -> None:
    """Create the engine and, in non-prod, the tables.

    Real projects manage schema with Alembic; `create_all` is used here to keep
    the reference implementation runnable with a single `docker compose up`.
    It is skipped in prod (see the guard below) so a production deploy never
    mutates a schema implicitly.
    """
    global _engine, _session_factory

    url = config.async_database_url
    if not url:
        logger.info("DATABASE_URL is not set - starting without a database")
        return

    _engine = create_async_engine(
        url,
        echo=config.db_echo,
        pool_size=config.db_pool_size,
        max_overflow=config.db_max_overflow,
        pool_recycle=config.db_pool_recycle_seconds,
        # Verifies a pooled connection is still alive before handing it out.
        # Important on Cloud Run, where instances idle and Cloud SQL may have
        # dropped the TCP connection in the meantime.
        pool_pre_ping=True,
    )
    _session_factory = async_sessionmaker(_engine, class_=AsyncSession, expire_on_commit=False)

    if create_tables and config.environment != "prod":
        async with _engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        logger.info("Database schema ensured (create_all)")

    logger.info("Database engine initialised")


async def close_db() -> None:
    """Dispose of the pool on shutdown so connections are released cleanly."""
    global _engine, _session_factory
    if _engine is not None:
        await _engine.dispose()
        logger.info("Database engine disposed")
    _engine = None
    _session_factory = None


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency yielding a transactional session.

    Commits on success, rolls back on any exception, always closes.
    """
    if _session_factory is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database is not configured for this deployment.",
        )

    async with _session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def check_connection() -> tuple[str, str | None]:
    """Probe the database for the readiness endpoint.

    Returns `(status, error)` where status is one of
    "disabled" | "ok" | "error" - never raises, so a database outage degrades
    the readiness payload instead of crashing the probe.
    """
    if _engine is None:
        return "disabled", None
    try:
        async with _engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return "ok", None
    except Exception as exc:  # noqa: BLE001 - probe must never raise
        logger.warning("Database health check failed: %s", exc)
        return "error", str(exc)
