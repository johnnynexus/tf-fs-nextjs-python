"""Schemas for the seismic dashboard.

These are the contract between the backend's aggregation and the frontend's
charts. Everything the dashboard renders is computed server-side and arrives
pre-shaped, so the browser does no aggregation work and the payload stays
small regardless of how many raw events USGS returned.
"""

from typing import Literal

from pydantic import BaseModel, Field

# USGS publishes a four-level alert. Mapped straight onto the status palette
# (good / warning / serious / critical) in the UI, with an icon and label -
# never colour alone.
AlertLevel = Literal["green", "yellow", "orange", "red"]

TimeWindow = Literal["day", "week", "month"]


class QuakeEvent(BaseModel):
    """A single earthquake, trimmed to what the dashboard actually renders."""

    id: str
    magnitude: float
    place: str
    # Milliseconds since epoch, as USGS supplies it. Kept numeric so the
    # frontend can format in the viewer's own locale and timezone.
    time: int
    depth_km: float
    longitude: float
    latitude: float
    url: str
    alert: AlertLevel | None = None
    tsunami: bool = False
    significance: int = 0


class TimeBucket(BaseModel):
    """One column of the events-over-time chart."""

    # ISO-8601 start of the bucket, UTC.
    start: str
    count: int
    # Largest magnitude within the bucket, for the tooltip.
    max_magnitude: float | None = None


class MagnitudeBin(BaseModel):
    """One bar of the magnitude histogram."""

    # Inclusive lower bound; the bin covers [lower, lower + width).
    lower: float
    upper: float
    label: str
    count: int


class RegionCount(BaseModel):
    """One bar of the top-regions chart."""

    region: str
    count: int
    max_magnitude: float


class QuakeStats(BaseModel):
    """Headline numbers for the KPI row - rendered as stat tiles, not a chart."""

    total_events: int
    max_magnitude: float | None = None
    # The event behind `max_magnitude`, used for the hero figure.
    strongest: QuakeEvent | None = None
    significant_count: int = Field(default=0, description="Events of magnitude 4.5 or greater.")
    tsunami_count: int = 0
    median_depth_km: float | None = None


class DepthMagnitudePoint(BaseModel):
    """One dot of the depth-versus-magnitude scatter."""

    depth_km: float
    magnitude: float
    place: str


class QuakeSummary(BaseModel):
    """Everything the dashboard needs, in one response."""

    window: TimeWindow
    min_magnitude: float
    # When the upstream data was fetched, so the UI can show its age.
    generated_at: str
    # True when this response came from the in-process cache rather than a
    # fresh upstream fetch. Surfaced in the UI as a small provenance detail.
    cached: bool = False

    stats: QuakeStats
    timeline: list[TimeBucket]
    magnitude_bins: list[MagnitudeBin]
    top_regions: list[RegionCount]
    depth_magnitude: list[DepthMagnitudePoint]
    recent_significant: list[QuakeEvent]
