# Backend - FastAPI

See the [root README](../../README.md) for the full picture. This file covers
the backend only.

## Layout

```
app/
  core/config.py     pydantic-settings; every env var is declared here
  core/logging.py    console logs locally, JSON for Cloud Logging elsewhere
  db/base.py         SQLAlchemy declarative base + timestamp mixin
  db/session.py      async engine, session dependency, health probe
  models/            ORM models
  schemas/           pydantic request/response models
  routers/           HTTP layer; thin, delegates to services
  services/          business logic, independently testable
  main.py            app factory, CORS, lifespan
tests/               pytest suite (async, in-process ASGI client)
```

## Endpoints

| Method | Path                | Notes                                        |
| ------ | ------------------- | -------------------------------------------- |
| GET    | `/health`           | Liveness. No I/O.                             |
| GET    | `/health/ready`     | Readiness, includes the database check.       |
| GET    | `/api/v1/hello`     | Example endpoint the frontend calls.          |
| GET    | `/api/v1/items`     | List items. 503 when no database configured.  |
| POST   | `/api/v1/items`     | Create an item. 503 when no database.         |
| GET    | `/docs`             | Swagger UI.                                   |

## Local development

Fastest path is `docker compose up` from the repo root. To run on the host:

```bash
cd apps/backend
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"          # or: uv pip install -e ".[dev]"
cp .env.example .env             # then edit as needed
uvicorn app.main:app --reload --port 8000
```

## Tests and lint

```bash
pytest                    # database tests skip when DATABASE_URL is unset
ruff check .
ruff format --check .
mypy app                  # advisory
```

To include the database tests, point `DATABASE_URL` at a live Postgres:

```bash
docker compose up -d db
DATABASE_URL=postgresql://app:app@localhost:5432/app pytest
```

## Database

The database is **optional by design**. With no `DATABASE_URL` the service
starts normally, `/health/ready` reports `"database": "disabled"`, and the
item routes return 503. That is what allows the default Terraform deployment
(`enable_database = false`) to skip Cloud SQL entirely without a code change.

Schema is created with `Base.metadata.create_all` at startup, and only outside
prod. A real service would use Alembic; that is the one shortcut taken here to
keep `docker compose up` a single command.
