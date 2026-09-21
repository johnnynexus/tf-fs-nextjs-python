"""A minimal async TTL cache.

Purpose-built rather than pulled from a library: the need is one dictionary
with expiry and a lock, and adding a dependency for that would be poor value.

The lock does real work. Without it, N concurrent requests arriving on a cold
cache would each fire their own upstream fetch (a "thundering herd"); with it,
the first caller fetches and the rest wait and reuse that result.

Scope is per-process. Cloud Run may run several instances, so each keeps its
own copy - which is fine for a short TTL over public data. A shared cache
(Redis/Memorystore) would only be worth it if the upstream were rate-limited
or the data expensive.
"""

from __future__ import annotations

import asyncio
import time
from collections.abc import Awaitable, Callable
from typing import Generic, TypeVar

T = TypeVar("T")


class TTLCache(Generic[T]):
    def __init__(self, ttl_seconds: float) -> None:
        self._ttl = ttl_seconds
        self._entries: dict[str, tuple[float, T]] = {}
        self._locks: dict[str, asyncio.Lock] = {}
        # Guards `_locks` itself, so two coroutines racing for the same key
        # cannot end up with two different lock objects.
        self._guard = asyncio.Lock()

    async def _lock_for(self, key: str) -> asyncio.Lock:
        async with self._guard:
            return self._locks.setdefault(key, asyncio.Lock())

    def get_fresh(self, key: str) -> T | None:
        """Return the cached value if present and unexpired, else None."""
        entry = self._entries.get(key)
        if entry is None:
            return None
        stored_at, value = entry
        if (time.monotonic() - stored_at) >= self._ttl:
            return None
        return value

    async def get_or_set(self, key: str, factory: Callable[[], Awaitable[T]]) -> tuple[T, bool]:
        """Return `(value, was_cached)`, calling `factory` only on a miss."""
        cached = self.get_fresh(key)
        if cached is not None:
            return cached, True

        lock = await self._lock_for(key)
        async with lock:
            # Re-check inside the lock: while waiting, the coroutine that held
            # it may already have populated the entry.
            cached = self.get_fresh(key)
            if cached is not None:
                return cached, True

            value = await factory()
            self._entries[key] = (time.monotonic(), value)
            return value, False

    def clear(self) -> None:
        self._entries.clear()
