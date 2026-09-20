"""Router registry.

`api_router` collects every versioned router behind the API prefix, so
`main.py` mounts exactly one thing and adding a resource means editing one
file.
"""

from fastapi import APIRouter

from app.routers import hello, items

api_router = APIRouter()
api_router.include_router(hello.router)
api_router.include_router(items.router)

__all__ = ["api_router"]
