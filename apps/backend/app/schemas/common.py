"""Response schemas shared across routers."""

from typing import Literal

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    """Liveness payload - intentionally cheap, no I/O."""

    status: Literal["ok"] = "ok"
    service: str = Field(..., description="Human-readable service name")
    environment: str = Field(..., description="local | dev | prod")
    release: str = Field(..., description="Git SHA or version stamped at build time")


class ReadinessResponse(BaseModel):
    """Readiness payload - includes dependency checks."""

    status: Literal["ok", "degraded"]
    environment: str
    release: str
    database: Literal["ok", "disabled", "error"]
    database_error: str | None = None


class HelloResponse(BaseModel):
    message: str
    environment: str
    # Echoed back so the frontend can prove the round trip used its input.
    name: str
