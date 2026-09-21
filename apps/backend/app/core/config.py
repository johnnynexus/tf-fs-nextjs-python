"""Application configuration.

All runtime configuration comes from environment variables, validated and typed
by pydantic-settings. Nothing is hardcoded per-environment: the same image runs
in local dev, dev, and prod with different env vars supplied by docker-compose
or by Cloud Run (which Terraform wires up).
"""

import json
from functools import lru_cache
from typing import Annotated, Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        # `.env` is only read for local development; in containers the values
        # arrive as real environment variables. Missing file is not an error.
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # --- Application ------------------------------------------------------
    app_name: str = "tf-fs-nextjs-python backend"
    environment: Literal["local", "dev", "prod"] = "local"
    debug: bool = False
    log_level: str = "INFO"

    # Version string, stamped by CI with the git SHA so a running service can
    # be traced back to the commit that produced its image.
    release: str = "dev"

    # Prefix for versioned business endpoints. `/health` deliberately sits
    # outside this prefix so platform probes never change with an API version.
    api_v1_prefix: str = "/api/v1"

    # --- HTTP server ------------------------------------------------------
    # Cloud Run injects PORT and expects the container to honour it.
    port: int = 8080
    host: str = "0.0.0.0"  # noqa: S104 - binding all interfaces is required in a container

    # --- CORS -------------------------------------------------------------
    # Comma-separated list, e.g. "http://localhost:3000,https://frontend-xyz.run.app".
    # The frontend can either call the backend directly from the browser (needs
    # this) or proxy through its own Next.js route handler (does not).
    # `NoDecode` stops pydantic-settings from JSON-parsing the env var before
    # the validator below sees it. Without it, CORS_ORIGINS="a,b" raises a
    # JSONDecodeError at import time instead of being split on commas.
    cors_origins: Annotated[list[str], NoDecode] = Field(
        default_factory=lambda: ["http://localhost:3000"]
    )

    @field_validator("cors_origins", mode="before")
    @classmethod
    def _split_cors_origins(cls, value: object) -> object:
        """Accept both a comma-separated string and a real list.

        Env vars are always strings; a JSON list is awkward to write in
        Terraform and docker-compose, so "a,b" is supported too.
        """
        if isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                return []
            # `NoDecode` disabled the automatic JSON pass, so handle the JSON
            # form here to keep both notations working.
            if stripped.startswith("["):
                return json.loads(stripped)
            return [origin.strip() for origin in stripped.split(",") if origin.strip()]
        return value

    # --- USGS earthquake feed ---------------------------------------------
    # The dashboard's data source. No API key required, which is why it was
    # chosen: a fresh clone works with no credentials to obtain.
    usgs_base_url: str = "https://earthquake.usgs.gov/fdsnws/event/1/query"
    usgs_timeout_seconds: float = 10.0

    # Responses are cached in-process for this long. USGS updates roughly once
    # a minute, so a short TTL keeps the dashboard live while collapsing a
    # burst of pageviews into a single upstream request.
    quakes_cache_ttl_seconds: int = 60

    # Upper bound on events pulled per request. Keeps both the upstream
    # payload and the JSON sent to the browser predictable.
    usgs_max_events: int = 2000

    # --- Database ---------------------------------------------------------
    # Optional on purpose: the service must start and serve /health and
    # /api/v1/hello with no database attached, which is how it is deployed by
    # default (enable_database = false in Terraform).
    database_url: str | None = None

    # Connection pool sizing. Cloud Run runs many small instances, so keep the
    # per-instance pool small to avoid exhausting Postgres max_connections.
    db_pool_size: int = 5
    db_max_overflow: int = 5
    db_pool_recycle_seconds: int = 1800
    db_echo: bool = False

    @property
    def database_enabled(self) -> bool:
        return bool(self.database_url)

    @property
    def async_database_url(self) -> str | None:
        """Normalise a standard Postgres URL to SQLAlchemy's asyncpg dialect.

        Accepts `postgresql://`, `postgres://` or an already-correct
        `postgresql+asyncpg://` URL so the same value works for psql, Alembic
        and this app.
        """
        if not self.database_url:
            return None
        url = self.database_url
        if url.startswith("postgresql+asyncpg://"):
            return url
        if url.startswith("postgresql://"):
            return url.replace("postgresql://", "postgresql+asyncpg://", 1)
        if url.startswith("postgres://"):
            return url.replace("postgres://", "postgresql+asyncpg://", 1)
        return url


@lru_cache
def get_settings() -> Settings:
    """Cached accessor so settings are parsed once per process.

    Tests clear the cache (`get_settings.cache_clear()`) when they need to
    exercise a different configuration.
    """
    return Settings()


settings = get_settings()
