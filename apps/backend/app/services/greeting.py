"""Business logic for the hello endpoint.

Trivial on purpose - the point is the shape: routers stay thin and delegate to
services, so the HTTP layer and the logic can be tested independently.
"""

from app.core.config import Settings


def build_greeting(name: str, settings: Settings) -> str:
    cleaned = name.strip() or "world"
    return f"Hello, {cleaned}! Greetings from the {settings.environment} backend."
