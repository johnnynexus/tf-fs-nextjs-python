"""Tests for the seismic dashboard slice.

No network. The fixture stands in for the USGS payload and httpx's
MockTransport stands in for the wire, so these run identically on a laptop
with no connectivity and in CI. A test suite that depends on a third-party
API is a test suite that fails for reasons unrelated to the code.
"""

import json
from datetime import UTC, datetime
from pathlib import Path

import httpx
import pytest

from app.core.config import Settings
from app.schemas.quake import QuakeEvent
from app.services import usgs_service
from app.services.cache import TTLCache

FIXTURE = json.loads((Path(__file__).parent / "fixtures" / "usgs_sample.json").read_text())
FEATURES = FIXTURE["features"]

# Matches the fixture's fixed epoch so bucketing assertions are deterministic.
NOW = datetime.fromtimestamp(1790000000, tz=UTC)


@pytest.fixture(autouse=True)
def _clear_cache():
    """The module-level cache would otherwise leak between tests."""
    usgs_service.clear_cache()
    yield
    usgs_service.clear_cache()


def mock_client(payload: object, status_code: int = 200) -> httpx.AsyncClient:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(status_code, json=payload)

    return httpx.AsyncClient(transport=httpx.MockTransport(handler))


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------


def test_parse_events_skips_unusable_rows() -> None:
    events = usgs_service.parse_events(FEATURES)

    # 11 features in, 3 unusable (null mag, null depth, null time).
    assert len(events) == 8
    assert all(isinstance(event, QuakeEvent) for event in events)
    assert "null-mag" not in {event.id for event in events}


def test_parse_event_keeps_real_zero_values() -> None:
    """A magnitude of 0.0 is real data, not a missing value."""
    feature = {
        "id": "zero",
        "properties": {"mag": 0.0, "place": "Somewhere, CA", "time": 1790000000000, "url": ""},
        "geometry": {"type": "Point", "coordinates": [1.0, 2.0, 0.0]},
    }

    event = usgs_service.parse_event(feature)

    assert event is not None
    assert event.magnitude == 0.0
    assert event.depth_km == 0.0


@pytest.mark.parametrize(
    ("place", "expected"),
    [
        ("15 km ESE of Anza, CA", "CA"),
        ("south of Africa", "Africa"),
        ("Kermadec Islands region", "Kermadec Islands region"),
        ("49 km NNE of Kainantu, Papua New Guinea", "Papua New Guinea"),
    ],
)
def test_extract_region(place: str, expected: str) -> None:
    assert usgs_service.extract_region(place) == expected


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------


def test_build_stats() -> None:
    stats = usgs_service.build_stats(usgs_service.parse_events(FEATURES))

    assert stats.total_events == 8
    assert stats.max_magnitude == 6.5
    assert stats.strongest is not None
    assert stats.strongest.id == "ci001"
    # M4.5+: 6.5, 4.8, 5.6, 4.6
    assert stats.significant_count == 4
    assert stats.tsunami_count == 1
    assert stats.median_depth_km is not None


def test_build_stats_handles_empty_input() -> None:
    stats = usgs_service.build_stats([])

    assert stats.total_events == 0
    assert stats.max_magnitude is None
    assert stats.strongest is None


def test_timeline_is_gap_free_and_correct_length() -> None:
    events = usgs_service.parse_events(FEATURES)

    timeline = usgs_service.build_timeline(events, "week", now=NOW)

    # 7 days of 6-hour buckets.
    assert len(timeline) == 28
    # Empty buckets are emitted, not omitted - the shape of quiet periods
    # is part of the story.
    assert any(bucket.count == 0 for bucket in timeline)
    assert sum(bucket.count for bucket in timeline) > 0
    # Monotonic, evenly spaced timestamps.
    starts = [datetime.fromisoformat(bucket.start) for bucket in timeline]
    assert starts == sorted(starts)


def test_timeline_day_window_uses_hourly_buckets() -> None:
    timeline = usgs_service.build_timeline([], "day", now=NOW)

    assert len(timeline) == 24
    assert all(bucket.count == 0 for bucket in timeline)


def test_magnitude_bins_cover_every_event() -> None:
    events = usgs_service.parse_events(FEATURES)

    bins = usgs_service.build_magnitude_bins(events)

    assert sum(b.count for b in bins) == len(events)
    # Five bands, matching the frontend's five-step ordinal ramp.
    assert len(bins) == 5
    # Top bin is open-ended and reported with a JSON-safe upper bound.
    assert bins[-1].label == "M6+"
    assert bins[-1].upper == 10.0
    # First band is labelled as a threshold, not a range starting at zero.
    assert bins[0].label == "<M3"


def test_top_regions_sorted_by_count() -> None:
    events = usgs_service.parse_events(FEATURES)

    regions = usgs_service.build_top_regions(events)

    assert regions[0].region == "CA"  # three CA events in the fixture
    assert regions[0].count == 3
    counts = [region.count for region in regions]
    assert counts == sorted(counts, reverse=True)


def test_depth_magnitude_is_capped_and_ranked() -> None:
    events = usgs_service.parse_events(FEATURES)

    points = usgs_service.build_depth_magnitude(events, limit=3)

    assert len(points) == 3
    assert [p.magnitude for p in points] == [6.5, 5.6, 4.8]


def test_build_summary_end_to_end() -> None:
    summary = usgs_service.build_summary(FEATURES, "week", 2.5, now=NOW)

    assert summary.window == "week"
    assert summary.min_magnitude == 2.5
    assert summary.stats.total_events == 8
    assert len(summary.timeline) == 28
    assert summary.magnitude_bins
    assert summary.top_regions
    assert summary.recent_significant
    # Serialisable: no inf/NaN, which would produce invalid JSON.
    json.dumps(summary.model_dump())


def test_summary_falls_back_when_nothing_is_significant() -> None:
    """A quiet window must still populate the table rather than show nothing."""
    quiet = [f for f in FEATURES if (f["properties"].get("mag") or 0) < 4.5]

    summary = usgs_service.build_summary(quiet, "week", 0.0, now=NOW)

    assert summary.stats.significant_count == 0
    assert summary.recent_significant  # falls back to strongest available


def test_build_summary_with_no_events() -> None:
    summary = usgs_service.build_summary([], "day", 2.5, now=NOW)

    assert summary.stats.total_events == 0
    assert len(summary.timeline) == 24
    assert summary.recent_significant == []
    json.dumps(summary.model_dump())


# ---------------------------------------------------------------------------
# Fetching and caching
# ---------------------------------------------------------------------------


async def test_fetch_raw_events_returns_features() -> None:
    async with mock_client(FIXTURE) as client:
        features = await usgs_service.fetch_raw_events("week", 2.5, Settings(), client)

    assert len(features) == len(FEATURES)


async def test_fetch_raises_upstream_error_on_http_error() -> None:
    async with mock_client({"detail": "boom"}, status_code=500) as client:
        with pytest.raises(usgs_service.UpstreamError):
            await usgs_service.fetch_raw_events("week", 2.5, Settings(), client)


async def test_fetch_raises_upstream_error_when_features_missing() -> None:
    async with mock_client({"metadata": {}}) as client:
        with pytest.raises(usgs_service.UpstreamError):
            await usgs_service.fetch_raw_events("week", 2.5, Settings(), client)


async def test_get_summary_caches_between_calls() -> None:
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        return httpx.Response(200, json=FIXTURE)

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        first = await usgs_service.get_summary("week", 2.5, Settings(), client)
        second = await usgs_service.get_summary("week", 2.5, Settings(), client)

    assert calls == 1, "second call should have been served from cache"
    assert first.cached is False
    assert second.cached is True
    assert first.stats.total_events == second.stats.total_events


async def test_cache_expires() -> None:
    cache: TTLCache[int] = TTLCache(ttl_seconds=0)
    calls = 0

    async def factory() -> int:
        nonlocal calls
        calls += 1
        return calls

    await cache.get_or_set("k", factory)
    _, was_cached = await cache.get_or_set("k", factory)

    assert calls == 2
    assert was_cached is False


async def test_cache_collapses_concurrent_misses() -> None:
    """The lock exists to stop N concurrent requests firing N upstream calls."""
    import asyncio

    cache: TTLCache[int] = TTLCache(ttl_seconds=60)
    calls = 0

    async def factory() -> int:
        nonlocal calls
        calls += 1
        await asyncio.sleep(0.01)
        return calls

    results = await asyncio.gather(*(cache.get_or_set("k", factory) for _ in range(10)))

    assert calls == 1
    assert all(value == 1 for value, _ in results)


# ---------------------------------------------------------------------------
# HTTP layer
# ---------------------------------------------------------------------------


async def test_summary_endpoint_returns_payload(client, monkeypatch) -> None:
    async def fake_fetch(window, min_magnitude, config=None, http_client=None):
        return FEATURES

    monkeypatch.setattr(
        usgs_service,
        "fetch_raw_events",
        lambda window, min_magnitude, config=None, client=None: fake_fetch(window, min_magnitude),
    )

    response = await client.get("/api/v1/quakes/summary", params={"window": "day"})

    assert response.status_code == 200
    body = response.json()
    assert body["window"] == "day"
    assert body["stats"]["total_events"] == 8
    assert len(body["timeline"]) == 24


async def test_summary_endpoint_returns_503_on_upstream_failure(client, monkeypatch) -> None:
    async def boom(*args, **kwargs):
        raise usgs_service.UpstreamError("upstream down")

    monkeypatch.setattr(usgs_service, "fetch_raw_events", boom)

    response = await client.get("/api/v1/quakes/summary")

    # 503, not 500 - this service is fine, its upstream is not.
    assert response.status_code == 503
    assert "unavailable" in response.json()["detail"].lower()


async def test_summary_endpoint_validates_magnitude(client) -> None:
    response = await client.get("/api/v1/quakes/summary", params={"min_magnitude": 99})

    assert response.status_code == 422


async def test_health_does_not_depend_on_usgs(client, monkeypatch) -> None:
    """A third-party outage must not fail the readiness probe."""

    async def boom(*args, **kwargs):
        raise usgs_service.UpstreamError("upstream down")

    monkeypatch.setattr(usgs_service, "fetch_raw_events", boom)

    assert (await client.get("/health")).status_code == 200
    ready = await client.get("/health/ready")
    assert ready.status_code == 200
    assert ready.json()["status"] == "ok"
