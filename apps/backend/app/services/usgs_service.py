"""Fetch and aggregate the USGS earthquake feed.

Split deliberately into two halves:

* `fetch_raw_events` does I/O and nothing else.
* `build_summary` and its helpers are pure functions over already-parsed
  data, so every aggregation rule is unit-testable with a fixture and the
  test suite never touches the network.

Why aggregate server-side at all: the raw 7-day feed is ~365 events and
~170 KB. Shipping that to the browser and bucketing it in JavaScript would
waste bandwidth and put the logic somewhere it cannot be tested as easily.
The browser receives a few KB of ready-to-render numbers instead.
"""

from __future__ import annotations

import logging
import statistics
from collections import defaultdict
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx

from app.core.config import Settings, settings
from app.schemas.quake import (
    DepthMagnitudePoint,
    MagnitudeBin,
    QuakeEvent,
    QuakeStats,
    QuakeSummary,
    RegionCount,
    TimeBucket,
    TimeWindow,
)
from app.services.cache import TTLCache

logger = logging.getLogger(__name__)


class UpstreamError(RuntimeError):
    """Raised when the USGS feed cannot be fetched or parsed."""


# How far back each window reaches, and how wide its timeline buckets are.
WINDOW_SPEC: dict[TimeWindow, tuple[timedelta, timedelta]] = {
    "day": (timedelta(days=1), timedelta(hours=1)),
    "week": (timedelta(days=7), timedelta(hours=6)),
    "month": (timedelta(days=30), timedelta(days=1)),
}

# Histogram edges, open-ended at the top.
#
# Five bands, not more, for two reasons. The feed is filtered to M2.5+, so
# finer bands below 3 are structurally always empty; and the ordinal colour
# ramp the frontend uses only has five steps that stay tellable apart (a
# sixth fails the adjacent-lightness check). These also line up with the
# conventional minor / light / moderate / strong / major grouping.
MAGNITUDE_EDGES: list[float] = [0, 3, 4, 5, 6]

# USGS calls anything at or above this "significant" for most purposes.
SIGNIFICANT_MAGNITUDE = 4.5

_cache: TTLCache[QuakeSummary] = TTLCache(ttl_seconds=settings.quakes_cache_ttl_seconds)


# ---------------------------------------------------------------------------
# I/O
# ---------------------------------------------------------------------------


async def fetch_raw_events(
    window: TimeWindow,
    min_magnitude: float,
    config: Settings = settings,
    client: httpx.AsyncClient | None = None,
) -> list[dict[str, Any]]:
    """Fetch the GeoJSON feed and return its raw `features` list.

    `client` is injectable so tests can supply a mock transport.
    """
    lookback, _ = WINDOW_SPEC[window]
    params = {
        "format": "geojson",
        "starttime": (datetime.now(UTC) - lookback).strftime("%Y-%m-%dT%H:%M:%S"),
        "minmagnitude": str(min_magnitude),
        "limit": str(config.usgs_max_events),
        "orderby": "time",
    }

    owns_client = client is None
    client = client or httpx.AsyncClient(timeout=config.usgs_timeout_seconds)
    try:
        response = await client.get(config.usgs_base_url, params=params)
        response.raise_for_status()
        payload = response.json()
    except httpx.HTTPError as exc:
        raise UpstreamError(f"USGS request failed: {exc}") from exc
    except ValueError as exc:  # malformed JSON
        raise UpstreamError(f"USGS returned invalid JSON: {exc}") from exc
    finally:
        if owns_client:
            await client.aclose()

    features = payload.get("features")
    if not isinstance(features, list):
        # Note: the query API's `metadata` has no `count` field (only the
        # separate /count endpoint does), so `features` is the only reliable
        # signal that the response is well-formed.
        raise UpstreamError("USGS response did not contain a 'features' list")

    return features


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------


def parse_event(feature: dict[str, Any]) -> QuakeEvent | None:
    """Convert one GeoJSON feature, or return None if it is unusable.

    Real USGS rows carry nulls: `mag` is null for some unreviewed events and
    depth can be missing. Those are skipped rather than coerced to zero,
    which would put phantom points at the origin of the scatter plot.
    """
    properties = feature.get("properties") or {}
    geometry = feature.get("geometry") or {}
    coordinates = geometry.get("coordinates") or []

    magnitude = properties.get("mag")
    if magnitude is None or len(coordinates) < 3 or coordinates[2] is None:
        return None

    event_time = properties.get("time")
    if event_time is None:
        return None

    try:
        return QuakeEvent(
            id=str(feature.get("id") or properties.get("code") or event_time),
            magnitude=float(magnitude),
            place=str(properties.get("place") or "Unknown location"),
            time=int(event_time),
            depth_km=round(float(coordinates[2]), 2),
            longitude=float(coordinates[0]),
            latitude=float(coordinates[1]),
            url=str(properties.get("url") or ""),
            alert=properties.get("alert") or None,
            tsunami=bool(properties.get("tsunami")),
            significance=int(properties.get("sig") or 0),
        )
    except (TypeError, ValueError):
        logger.warning("Skipping malformed USGS feature: %s", feature.get("id"))
        return None


def parse_events(features: list[dict[str, Any]]) -> list[QuakeEvent]:
    parsed = (parse_event(feature) for feature in features)
    return [event for event in parsed if event is not None]


# ---------------------------------------------------------------------------
# Aggregation - pure functions, no I/O
# ---------------------------------------------------------------------------


def build_timeline(
    events: list[QuakeEvent], window: TimeWindow, now: datetime | None = None
) -> list[TimeBucket]:
    """Bucket events into a fixed, gap-free series.

    Every bucket in the window is emitted, including empty ones. A chart that
    silently omits quiet hours misrepresents the shape of the data.
    """
    lookback, step = WINDOW_SPEC[window]
    now = now or datetime.now(UTC)

    # Align the right edge to a step boundary so bucket labels are tidy.
    step_seconds = int(step.total_seconds())
    end_epoch = (int(now.timestamp()) // step_seconds + 1) * step_seconds
    start_epoch = end_epoch - int(lookback.total_seconds())

    counts: dict[int, int] = defaultdict(int)
    peaks: dict[int, float] = {}
    for event in events:
        seconds = event.time // 1000
        if seconds < start_epoch or seconds >= end_epoch:
            continue
        bucket = (seconds - start_epoch) // step_seconds
        counts[bucket] += 1
        peaks[bucket] = max(peaks.get(bucket, event.magnitude), event.magnitude)

    total_buckets = int(lookback.total_seconds()) // step_seconds
    return [
        TimeBucket(
            start=datetime.fromtimestamp(start_epoch + index * step_seconds, tz=UTC).isoformat(),
            count=counts.get(index, 0),
            max_magnitude=round(peaks[index], 1) if index in peaks else None,
        )
        for index in range(total_buckets)
    ]


def build_magnitude_bins(events: list[QuakeEvent]) -> list[MagnitudeBin]:
    """Histogram over fixed magnitude bands, top band open-ended."""
    bins: list[MagnitudeBin] = []
    for index, lower in enumerate(MAGNITUDE_EDGES):
        is_last = index == len(MAGNITUDE_EDGES) - 1
        upper = float("inf") if is_last else MAGNITUDE_EDGES[index + 1]
        count = sum(1 for event in events if lower <= event.magnitude < upper)
        if is_last:
            label = f"M{lower}+"
        elif index == 0:
            # "M0–3" would imply the feed contains sub-M2.5 events; it does not.
            label = f"<M{upper}"
        else:
            label = f"M{lower}–{upper}"

        bins.append(
            MagnitudeBin(
                lower=float(lower),
                # inf is not valid JSON; cap the reported upper bound.
                upper=10.0 if is_last else float(upper),
                label=label,
                count=count,
            )
        )
    return bins


def extract_region(place: str) -> str:
    """Reduce a USGS place string to a region for grouping.

    USGS formats these as "15 km ESE of Anza, CA" or "south of Africa". The
    text after the last comma is the useful grouping key; when there is no
    comma the whole string is used, with any leading distance prefix removed.
    """
    if "," in place:
        return place.rsplit(",", 1)[1].strip() or place.strip()

    cleaned = place.strip()
    for separator in (" of ",):
        if separator in cleaned:
            return cleaned.split(separator, 1)[1].strip()
    return cleaned


def build_top_regions(events: list[QuakeEvent], limit: int = 8) -> list[RegionCount]:
    grouped: dict[str, list[float]] = defaultdict(list)
    for event in events:
        grouped[extract_region(event.place)].append(event.magnitude)

    regions = [
        RegionCount(region=region, count=len(mags), max_magnitude=round(max(mags), 1))
        for region, mags in grouped.items()
    ]
    # Count first, magnitude as the tiebreaker, so the ordering is stable.
    regions.sort(key=lambda row: (row.count, row.max_magnitude), reverse=True)
    return regions[:limit]


def build_stats(events: list[QuakeEvent]) -> QuakeStats:
    if not events:
        return QuakeStats(total_events=0)

    strongest = max(events, key=lambda event: event.magnitude)
    return QuakeStats(
        total_events=len(events),
        max_magnitude=round(strongest.magnitude, 1),
        strongest=strongest,
        significant_count=sum(1 for event in events if event.magnitude >= SIGNIFICANT_MAGNITUDE),
        tsunami_count=sum(1 for event in events if event.tsunami),
        median_depth_km=round(statistics.median(e.depth_km for e in events), 1),
    )


def build_depth_magnitude(events: list[QuakeEvent], limit: int = 600) -> list[DepthMagnitudePoint]:
    """Points for the scatter plot.

    Capped so a busy window cannot ship thousands of overlapping dots. The
    strongest events are kept, since they are the ones worth seeing.
    """
    ranked = sorted(events, key=lambda event: event.magnitude, reverse=True)[:limit]
    return [
        DepthMagnitudePoint(depth_km=event.depth_km, magnitude=event.magnitude, place=event.place)
        for event in ranked
    ]


def build_summary(
    features: list[dict[str, Any]],
    window: TimeWindow,
    min_magnitude: float,
    now: datetime | None = None,
) -> QuakeSummary:
    """Turn raw GeoJSON features into everything the dashboard renders."""
    events = parse_events(features)
    now = now or datetime.now(UTC)

    significant = sorted(
        (e for e in events if e.magnitude >= SIGNIFICANT_MAGNITUDE),
        key=lambda event: event.time,
        reverse=True,
    )[:10]
    # A quiet window can contain nothing "significant"; fall back to the
    # strongest events so the table is never empty.
    if not significant:
        significant = sorted(events, key=lambda event: event.magnitude, reverse=True)[:10]

    return QuakeSummary(
        window=window,
        min_magnitude=min_magnitude,
        generated_at=now.isoformat(),
        stats=build_stats(events),
        timeline=build_timeline(events, window, now=now),
        magnitude_bins=build_magnitude_bins(events),
        top_regions=build_top_regions(events),
        depth_magnitude=build_depth_magnitude(events),
        recent_significant=significant,
    )


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------


async def get_summary(
    window: TimeWindow,
    min_magnitude: float,
    config: Settings = settings,
    client: httpx.AsyncClient | None = None,
) -> QuakeSummary:
    """Cached summary for one (window, magnitude) combination."""
    key = f"{window}:{min_magnitude}"

    async def factory() -> QuakeSummary:
        features = await fetch_raw_events(window, min_magnitude, config, client)
        logger.info(
            "Fetched %d USGS features (window=%s, min_magnitude=%s)",
            len(features),
            window,
            min_magnitude,
        )
        return build_summary(features, window, min_magnitude)

    summary, was_cached = await _cache.get_or_set(key, factory)
    # Report provenance without mutating the cached object.
    return summary.model_copy(update={"cached": was_cached})


def clear_cache() -> None:
    """Test hook, and useful for a manual refresh."""
    _cache.clear()
