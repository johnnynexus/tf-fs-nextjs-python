# Frontend - Next.js (App Router)

See the [root README](../../README.md) for the full picture.

## How the frontend reaches the backend

Two paths, both exercised on the home page:

| Caller                 | Path                                  | Env var                            |
| ---------------------- | ------------------------------------- | ---------------------------------- |
| Server Component (SSR) | direct to backend                     | `BACKEND_INTERNAL_URL` (runtime)   |
| Browser (default)      | `/api/backend/*` proxy on this server | `BACKEND_INTERNAL_URL` (runtime)   |
| Browser (opt-in)       | direct, cross-origin                  | `NEXT_PUBLIC_API_BASE_URL` (build) |

The proxy is the default because `NEXT_PUBLIC_*` values are inlined by
`next build`, but the backend's Cloud Run URL only exists after Terraform
applies. Proxying keeps one image valid for every environment and removes the
CORS preflight. The direct path is kept working so the cross-origin setup (and
the backend's `CORS_ORIGINS`) is demonstrated rather than merely described.

## Local development

```bash
cd apps/frontend
npm ci
cp .env.example .env.local
npm run dev          # http://localhost:3000
```

Or run the whole stack with `docker compose up` from the repo root.

## Checks

```bash
npm run typecheck     # tsc --noEmit
npm run lint          # eslint via next lint
npm run format:check  # prettier
npm run build         # production build (also type-checks and lints)
```
