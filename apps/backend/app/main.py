"""FastAPI application factory and entrypoint.

Run locally:      uvicorn app.main:app --reload --port 8000
Run in container: see Dockerfile (honours $PORT, which Cloud Run sets).
"""

import logging
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.logging import configure_logging
from app.db.session import close_db, init_db
from app.routers import api_router
from app.routers.health import router as health_router

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Startup/shutdown hooks.

    Startup must not raise on a database problem: Cloud Run would fail the
    revision and roll back the whole deploy over a dependency the service can
    run without. The failure is logged and surfaced by /health/ready instead.
    """
    configure_logging(settings)
    logger.info(
        "Starting %s (environment=%s, release=%s, database=%s)",
        settings.app_name,
        settings.environment,
        settings.release,
        "enabled" if settings.database_enabled else "disabled",
    )
    try:
        await init_db(settings)
    except Exception:
        logger.exception("Database initialisation failed - continuing without it")

    yield

    await close_db()
    logger.info("Shutdown complete")


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.app_name,
        version=settings.release,
        description=(
            "Reference FastAPI backend. Health endpoints are unversioned; "
            "business endpoints live under the API prefix."
        ),
        lifespan=lifespan,
        # Docs are always on here because this is a reference implementation.
        # For a real production service, gate these on `settings.debug`.
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
    )

    # CORS is only needed when the browser calls this service directly. The
    # frontend's default path proxies through its own Next.js route handler
    # (same origin, no preflight), but direct calls are supported so the
    # split-origin setup is demonstrated too.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        max_age=600,
    )

    app.include_router(health_router)
    app.include_router(api_router, prefix=settings.api_v1_prefix)

    return app


app = create_app()


if __name__ == "__main__":
    # `python -m app.main` convenience path; production uses the uvicorn CLI.
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.environment == "local",
    )
