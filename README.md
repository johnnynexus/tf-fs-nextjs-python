# tf-fs-nextjs-python

A reference full-stack monorepo: **Next.js** frontend, **FastAPI** backend,
**Terraform** infrastructure on **Google Cloud Run**, and **GitHub Actions**
CI/CD using OIDC — no long-lived cloud credentials anywhere.

It ships a live **seismic dashboard** at `/dashboard`: USGS earthquake data
fetched and aggregated by the backend, charted in hand-rolled SVG with no
charting library.

Everything here runs. `docker compose up` gives you a working local stack with
hot reload and a real Postgres; the Terraform plans cleanly; the workflows
pass `actionlint`.

---

## Contents

- [Architecture](#architecture)
- [Repository layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Local development](#local-development)
- [How the frontend talks to the backend](#how-the-frontend-talks-to-the-backend)
- [Deploying](#deploying)
- [CI/CD, end to end](#cicd-end-to-end)
- [Configuration reference](#configuration-reference)
- [Design decisions](#design-decisions)
- [Troubleshooting](#troubleshooting)

---

## Architecture

```
                         ┌──────────────────────────────┐
  Browser  ──── HTTPS ──►│  Cloud Run: frontend         │
                         │  Next.js 15 (App Router)     │
                         │                              │
                         │  • Server Components         │
                         │  • /api/backend/* proxy      │
                         └───────────┬──────────────────┘
                                     │  HTTPS, server-to-server
                                     │  (BACKEND_INTERNAL_URL, runtime env)
                                     ▼
                         ┌──────────────────────────────┐
                         │  Cloud Run: backend          │
                         │  FastAPI + uvicorn           │
                         └───────────┬──────────────────┘
                                     │  private IP, direct VPC egress
                                     │  (only when enable_database = true)
                                     ▼
                         ┌──────────────────────────────┐
                         │  Cloud SQL: Postgres         │
                         │  password in Secret Manager  │
                         └──────────────────────────────┘

  Artifact Registry  ──── images pulled by both Cloud Run services
  GCS bucket         ──── Terraform remote state (versioned, locked)
```

Both services scale to zero. With the database off (the default), an idle
environment costs approximately nothing.

## Repository layout

```
.
├── apps/
│   ├── frontend/          Next.js 15, App Router, TypeScript, Tailwind
│   │   ├── src/app/       routes, incl. /dashboard and the /api/backend proxy
│   │   ├── src/lib/api.ts typed API client
│   │   ├── src/lib/viz.ts scales, ticks, path builders (replaces a chart lib)
│   │   ├── src/components/charts/     hand-rolled SVG charts
│   │   └── Dockerfile     multi-stage; dev stage + standalone runtime
│   └── backend/           FastAPI
│       ├── app/core/      pydantic-settings config, logging
│       ├── app/db/        async SQLAlchemy engine + session
│       ├── app/services/usgs_service.py   USGS fetch + aggregation
│       ├── app/routers/   HTTP layer (thin)
│       ├── app/services/  business logic
│       ├── tests/         pytest, async, in-process ASGI client
│       └── Dockerfile     multi-stage; venv built then copied
├── infra/terraform/       see infra/terraform/README.md
├── .github/workflows/     see docs/cicd.md
├── docs/                  architecture, setup, CI/CD deep dives
└── docker-compose.yml     local dev: frontend + backend + Postgres
```

## Prerequisites

Local development needs only:

| Tool           | Version   | Notes                              |
| -------------- | --------- | ---------------------------------- |
| Docker Desktop | any recent | Includes Compose v2.                |
| Git            | any       |                                     |

To work on an app outside Docker, or to deploy:

| Tool        | Version | Used for                       |
| ----------- | ------- | ------------------------------ |
| Node.js     | >= 20   | frontend                       |
| Python      | >= 3.11 | backend                        |
| Terraform   | >= 1.6  | infrastructure                 |
| gcloud CLI  | latest  | GCP auth, image pushes         |

## Local development

```bash
git clone <this-repo> && cd tf-fs-nextjs-python
docker compose up --build
```

| Service   | URL                            |
| --------- | ------------------------------ |
| Frontend  | http://localhost:3000          |
| Dashboard | http://localhost:3000/dashboard |
| Backend   | http://localhost:8000          |
| API docs  | http://localhost:8000/docs     |
| Postgres  | localhost:5432 (`app`/`app`/`app`) |

The home page performs two independent round trips to the backend — one from
the Next.js server during SSR, one from your browser — and shows the result of
each. Both green means the stack is wired correctly.

Both app containers hot-reload against bind-mounted source, so this is a real
development environment, not a demo.

No `.env` file is required; every value has a working default. If a port is
already taken (a local Postgres on 5432 is the usual culprit):

```bash
cp .env.example .env    # then edit POSTGRES_HOST_PORT etc.
```

### Running an app on the host

```bash
# Backend
cd apps/backend
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env
uvicorn app.main:app --reload --port 8000

# Frontend
cd apps/frontend
npm ci
cp .env.example .env.local
npm run dev
```

### Tests and linting

```bash
# Backend
cd apps/backend
pytest                       # database tests skip without DATABASE_URL
ruff check . && ruff format --check .

# with the database, so the item tests actually run:
docker compose up -d db
DATABASE_URL=postgresql://app:app@localhost:5432/app pytest

# Frontend
cd apps/frontend
npm run typecheck && npm run lint && npm run format:check && npm run build

# Terraform
cd infra/terraform
terraform fmt -check -recursive
(cd environments/dev && terraform init -backend=false && terraform validate)
```

## How the frontend talks to the backend

This is the part most reference repos get hand-wavy about, so it is explicit
here. There are three paths, and all three work:

| Caller                    | Route                                 | Configured by                       |
| ------------------------- | ------------------------------------- | ----------------------------------- |
| Server Component (SSR)    | straight to the backend               | `BACKEND_INTERNAL_URL` (runtime)    |
| Browser — **default**     | `/api/backend/*` proxy on the frontend | `BACKEND_INTERNAL_URL` (runtime)    |
| Browser — opt-in          | direct, cross-origin                  | `NEXT_PUBLIC_API_BASE_URL` (build)  |

**The proxy is the default, and the reason is ordering.** `NEXT_PUBLIC_*`
values are inlined into the JS bundle by `next build`, but the backend's Cloud
Run URL does not exist until `terraform apply` has run. Baking it in would
mean building the image, applying, then rebuilding the image. Proxying through
a server route reads the target at *request* time from an env var Terraform
sets, so one image is valid in every environment — and browser requests are
same-origin, so there is no CORS preflight.

The direct cross-origin path is kept working (and the backend's
`CORS_ORIGINS` is real, tested configuration) so the split-origin setup is
demonstrated rather than just described. To use it: build the frontend image
with `NEXT_PUBLIC_API_BASE_URL` set, and add the frontend's origin to
`additional_cors_origins` in the environment's tfvars.

## Deploying

Full detail in [`infra/terraform/README.md`](infra/terraform/README.md). The
short version:

```bash
# 1. Once per GCP project: state bucket + GitHub OIDC federation
cd infra/terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # edit it
terraform init && terraform apply
terraform output github_configuration_summary  # -> paste into GitHub

# 2. Per environment
cd ../environments/dev
# edit terraform.tfvars (project_id) and backend.hcl (state bucket)
terraform init -backend-config=backend.hcl
terraform apply

# 3. URLs
terraform output frontend_url
terraform output backend_url
```

The first apply deploys a public placeholder image, because the registry it
creates has no images in it yet. CI replaces it on the next merge to main.

## CI/CD, end to end

Four workflows. Detail in [`docs/cicd.md`](docs/cicd.md).

```
Pull request
   └─► ci.yml
         ├─ detect changes (dorny/paths-filter)
         ├─ frontend:  typecheck · lint · format · build      [if changed]
         ├─ backend:   ruff · mypy · pytest + real Postgres   [if changed]
         │             matrix: Python 3.11 and 3.12
         ├─ terraform: fmt · init · validate                  [if changed]
         │             matrix: bootstrap, dev, prod
         └─ ci-passed: single required status check

Merge to main
   └─► build-and-push.yml
         ├─ detect which apps changed
         ├─ build matrix ──► _docker-build.yml  (reusable, per app)
         │                     OIDC auth · buildx · GHA layer cache
         │                     push to Artifact Registry, tagged with the SHA
         └─► deploy.yml (dev, automatic)

Manual promotion
   └─► deploy.yml (workflow_dispatch, environment: prod)
         ├─ [prod GitHub Environment gate — required reviewers]
         ├─ build images for the target environment
         ├─ resolve image refs (reuse what is deployed for unbuilt apps)
         ├─ terraform init · fmt · validate · plan  ──► job summary
         ├─ terraform apply <saved plan>
         └─ smoke test /health and /api/health
```

Points worth calling out:

- **No long-lived cloud credentials.** Workload Identity Federation exchanges
  a GitHub OIDC token for a short-lived GCP credential. The repository needs
  zero GitHub *secrets* — only non-sensitive Environment *variables*.
- **Path filters** mean a frontend-only PR never starts Python or Postgres,
  and a docs-only PR runs nothing but the final gate.
- **Reusable workflow** (`_docker-build.yml`) holds the build/auth/push steps
  once; frontend and backend are matrix legs, not copy-paste.
- **The applied plan is the reviewed plan.** `terraform plan -out=tfplan`
  followed by `terraform apply tfplan` in the same job, so nothing drifts in
  between.
- **Images deploy by digest**, not by tag, so a revision is pinned to exactly
  the bytes CI built.
- **Partial deploys are safe.** If only the frontend changed, the deploy reads
  the backend's currently running image from Cloud Run and reuses it, instead
  of reverting it to the bootstrap placeholder.

### One-time GitHub setup

Create Environments `dev` and `prod` (Settings → Environments), add **required
reviewers** to `prod`, and set these **variables** (not secrets — none are
sensitive) in each:

| Variable                         | Source                                          |
| -------------------------------- | ----------------------------------------------- |
| `GCP_PROJECT_ID`                 | your project                                     |
| `GCP_REGION`                     | e.g. `us-west1`                                  |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | bootstrap output                                 |
| `GCP_SERVICE_ACCOUNT`            | bootstrap output                                 |
| `TF_STATE_BUCKET`                | bootstrap output                                 |
| `TF_PROJECT_NAME`                | must match `project_name` in the env's tfvars    |

## Configuration reference

No secrets are committed. Only `.env.example` files, and tfvars containing
nothing sensitive.

### Backend

| Variable        | Default                 | Purpose                                              |
| --------------- | ----------------------- | ---------------------------------------------------- |
| `ENVIRONMENT`   | `local`                 | `local` \| `dev` \| `prod`                            |
| `PORT`          | `8080`                  | Cloud Run overrides this.                             |
| `CORS_ORIGINS`  | `http://localhost:3000` | Comma-separated origins.                              |
| `DATABASE_URL`  | unset                   | Unset ⇒ the app runs without a database.              |
| `LOG_LEVEL`     | `INFO`                  |                                                       |
| `RELEASE`       | `dev`                   | Git SHA; surfaced by `/health`.                       |

### Frontend

| Variable                   | When      | Purpose                                        |
| -------------------------- | --------- | ---------------------------------------------- |
| `BACKEND_INTERNAL_URL`     | runtime   | Where the Next.js server reaches the backend.   |
| `NEXT_PUBLIC_API_BASE_URL` | **build** | Set only for direct browser→backend calls.      |
| `NEXT_PUBLIC_RELEASE`      | build     | Git SHA.                                        |

### API endpoints

| Method | Path              | Notes                                   |
| ------ | ----------------- | --------------------------------------- |
| GET    | `/health`         | Liveness. No I/O.                        |
| GET    | `/health/ready`   | Readiness, including the database check. |
| GET    | `/api/v1/hello`   | Example endpoint the frontend calls.     |
| GET    | `/api/v1/items`   | 503 when no database is configured.      |
| POST   | `/api/v1/items`   | 503 when no database is configured.      |
| GET    | `/api/v1/quakes/summary` | Aggregated USGS data for the dashboard. 503 if USGS is unreachable. |
| POST   | `/api/v1/quakes/cache/clear` | Drop the cached summaries.   |

## Design decisions

**Cloud Run for both services.** The frontend uses Server Components and a
server-side proxy route, so it is not a static site and cannot go on
S3/CloudFront. Putting both on the same platform means one registry, one IAM
model, one log sink, one CI auth story — and both scale to zero. Trade-off:
no global edge cache; add Cloud CDN behind an HTTPS load balancer if needed.

**The database is optional and off by default.** Cloud SQL has no free tier
and bills whether or not it is used. The backend treats the database as a
dependency it can live without: `/health` and `/api/v1/hello` work, the item
routes return 503, and readiness reports `"database": "disabled"` instead of
failing. Turning it on is one tfvars flag.

**Startup never fails on a database error.** If it did, Cloud Run would reject
the revision and roll back an entire deploy because of a dependency the
service can run without. The error is logged and surfaced by
`/health/ready`.

**Liveness probes hit `/health`, not `/health/ready`.** A failing liveness
probe restarts the container; restarting a healthy frontend because the
backend is down makes an outage worse, not better.

**One base module for both Cloud Run services.** `modules/cloud_run_service`
holds identity, probes, scaling, secrets and VPC wiring;
`modules/frontend` and `modules/backend` add only what genuinely differs.

**Environments are directories, not workspaces.** Explicit targets, per-env
backend config, and no chance of applying to prod because a workspace was left
selected.

**No charting library.** The dashboard's scales, ticks and path builders are
about 200 lines in `src/lib/viz.ts`. That is less code than the configuration
needed to force a charting library to match the required mark specs, adds
nothing to the bundle (the whole `/dashboard` route is ~7 kB), and avoids the
React 19 peer-dependency churn. Chart colour comes from a validated palette in
`globals.css`, with separate ramps for continuous magnitude, ordered bands and
identity — and the ordered ramp is capped at five steps because a sixth fails
the adjacent-lightness check.

**Third-party data degrades one page, not the service.** If USGS is
unreachable the dashboard renders an explanatory empty state and the API
returns 503, while `/health` and `/health/ready` stay green. Readiness must
never be hostage to someone else's uptime — the same rule the database
follows.

**No CORS dependency cycle.** The backend is not given the frontend's URL
automatically, because the frontend needs the backend's URL — that would be a
cycle. It does not need breaking: the browser reaches the backend through the
frontend's same-origin proxy.

## Troubleshooting

**`docker compose up` fails: "port is already allocated".** Something on your
machine owns that port. `cp .env.example .env` and change
`POSTGRES_HOST_PORT` / `BACKEND_HOST_PORT` / `FRONTEND_HOST_PORT`.

**Home page shows "unreachable".** The frontend container could not reach the
backend. Inside Compose the target is `http://backend:8000`, not `localhost`.
Check `docker compose logs backend` and the `BACKEND_INTERNAL_URL` value.

**`/api/v1/items` returns 503.** Expected with no database.
`GET /health/ready` will say `"database": "disabled"`. Start Postgres
(`docker compose up -d db`) or set `enable_database = true` in tfvars.

**First `terraform apply` deploys "hello world".** Expected. The registry is
created by the same stack, so there is no image to deploy yet. Push images and
re-apply, or merge to main and let CI do it.

**`terraform destroy` fails on prod.** Deletion protection. Set
`service_deletion_protection = false` and `database_deletion_protection =
false`, apply, then destroy.

**GitHub Actions: "unable to get credentials".** The Workload Identity
Federation trust is scoped to one repository. Confirm `github_repository` in
the bootstrap tfvars matches `owner/repo` exactly, and that the workflow job
has `permissions: id-token: write`.

**Cloud Run rejects `allUsers`.** Your organisation enforces
`constraints/iam.allowedPolicyMemberDomains`. Set `backend_public = false` and
put an Identity-Aware Proxy load balancer in front of the frontend.

---

## Further reading

- [`docs/architecture.md`](docs/architecture.md) — components and request flow
- [`docs/setup.md`](docs/setup.md) — first-run setup, start to finish
- [`docs/cicd.md`](docs/cicd.md) — workflow-by-workflow walkthrough
- [`infra/terraform/README.md`](infra/terraform/README.md) — init, plan, apply, destroy
- [`apps/backend/README.md`](apps/backend/README.md)
- [`apps/frontend/README.md`](apps/frontend/README.md)
