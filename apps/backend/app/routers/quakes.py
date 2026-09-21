"""Seismic dashboard endpoints.

Backed by the public USGS feed. Unlike the item routes, these need no
database - which is why the dashboard works on the default deployment with
`enable_database = false`.
"""

import logging

from fastapi import APIRouter, HTTPException, Query, status

from app.schemas.quake import QuakeSummary, TimeWindow
from app.services import usgs_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/quakes", tags=["quakes"])


@router.get(
    "/summary",
    response_model=QuakeSummary,
    summary="Aggregated earthquake activity for the dashboard",
)
async def quake_summary(
    window: TimeWindow = Query(
        default="week",
        description="Look-back period: day (1h buckets), week (6h), month (1d).",
    ),
    min_magnitude: float = Query(
        default=2.5,
        ge=0,
        le=10,
        description="Lowest magnitude to include. Smaller values return far more events.",
    ),
) -> QuakeSummary:
    try:
        return await usgs_service.get_summary(window, min_magnitude)
    except usgs_service.UpstreamError as exc:
        # 503, not 500: this service is healthy, its upstream is not. The
        # distinction matters - /health and /health/ready deliberately do not
        # depend on USGS, so a third-party outage degrades one page rather
        # than failing the readiness probe and cycling the revision.
        logger.warning("USGS upstream failure: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Earthquake data is temporarily unavailable upstream.",
        ) from exc


@router.post(
    "/cache/clear",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Drop the cached summaries",
)
async def clear_cache() -> None:
    """Force the next request to hit USGS. Useful when demoing live updates."""
    usgs_service.clear_cache()
