"""Health endpoints.

Two distinct checks, because platforms use them differently:

* GET /health        - liveness. No I/O. If this fails the container is broken
                       and should be restarted.
* GET /health/ready  - readiness. Includes dependency checks. A failing
                       database makes this "degraded" but still returns 200,
                       because the service can serve most routes without it.
"""

from fastapi import APIRouter

from app.core.config import settings
from app.db.session import check_connection
from app.schemas.common import HealthResponse, ReadinessResponse

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse, summary="Liveness probe")
async def health() -> HealthResponse:
    return HealthResponse(
        service=settings.app_name,
        environment=settings.environment,
        release=settings.release,
    )


@router.get("/health/ready", response_model=ReadinessResponse, summary="Readiness probe")
async def readiness() -> ReadinessResponse:
    db_status, db_error = await check_connection()
    return ReadinessResponse(
        status="degraded" if db_status == "error" else "ok",
        environment=settings.environment,
        release=settings.release,
        database=db_status,
        database_error=db_error,
    )
