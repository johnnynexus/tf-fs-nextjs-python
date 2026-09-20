# CI/CD

Four workflows in `.github/workflows/`:

| File                 | Trigger                        | Does                                    |
| -------------------- | ------------------------------ | --------------------------------------- |
| `ci.yml`             | every PR, pushes to `main`     | lint, test, validate                     |
| `build-and-push.yml` | merge to `main`                | build + push images, then deploy dev     |
| `deploy.yml`         | called, or manual dispatch     | terraform plan/apply + smoke test        |
| `_docker-build.yml`  | `workflow_call` only           | reusable single-image build and push     |

## Authentication: OIDC, no stored keys

Every job that touches GCP authenticates through Workload Identity
Federation:

```
GitHub mints an OIDC token for the workflow run
  └─► the WIF provider validates issuer + attribute_condition
        (assertion.repository == "owner/repo")
      └─► STS exchanges it for a short-lived Google credential
            └─► which impersonates the deployer service account
```

No service account key is ever created, downloaded, stored or rotated. The
repository needs **zero GitHub secrets** — the configuration values are
non-sensitive Environment *variables*.

Two requirements, easy to get wrong:

- The job must declare `permissions: id-token: write`. Without it, no token
  is minted and `google-github-actions/auth` fails.
- The `attribute_condition` in `infra/terraform/bootstrap` must name your
  repository exactly. It is the security boundary — without it, any GitHub
  repository could authenticate against your pool.

## `ci.yml`

Runs on every pull request. No cloud credentials at any point:
`terraform init -backend=false` skips remote state entirely.

```
changes ──┬─► frontend   (if apps/frontend changed)
          ├─► backend    (if apps/backend changed)   matrix: py3.11, py3.12
          ├─► terraform  (if infra changed)          matrix: bootstrap, dev, prod
          └─► ci-passed  (always)
```

**Path filters.** `dorny/paths-filter` decides which jobs run. A
frontend-only PR never starts Python or Postgres; a docs-only PR runs nothing
but the gate.

**The backend job runs a real Postgres** as a service container, so the
database-backed tests actually execute in CI instead of silently skipping.

**The Python matrix** covers 3.12 (what the Docker image uses) and 3.11 (the
declared minimum), so a 3.12-only syntax slip is caught.

**`ci-passed`** exists because branch protection cannot require a job that
legitimately skips. It runs with `if: always()`, inspects
`needs.*.result`, and fails only on a real failure or cancellation. Make this
the one required status check.

## `_docker-build.yml` (reusable)

Called with a matrix, so the auth / buildx / cache / tag / push sequence is
written once rather than duplicated per app.

Notable choices:

- **Two tags per build**: the immutable git SHA (what gets deployed) and
  `latest` (a pointer for humans).
- **Outputs a digest-pinned reference** (`repo@sha256:…`). Terraform deploys
  that, so a revision is pinned to exactly the bytes this run built even if
  the tag is later moved.
- **GitHub Actions layer cache** (`cache-from/to: type=gha`, scoped per app),
  so unchanged dependency layers are cache hits.
- **`provenance: false`** — Cloud Run rejects the default OCI provenance
  attestation that buildx attaches.
- **`NEXT_PUBLIC_*` are build args**, because Next inlines them at build
  time. `NEXT_PUBLIC_API_BASE_URL` is deliberately left unset so the browser
  uses the frontend's same-origin proxy.

## `build-and-push.yml`

On merge to `main`:

1. `changes` emits a **JSON array** of apps to build.
2. `build` uses `strategy.matrix.app: ${{ fromJSON(...) }}`.
3. `deploy` calls `deploy.yml` for dev.

The matrix is built dynamically because a job-level `if` cannot skip an
individual matrix leg — emitting `["frontend"]` is what actually stops the
backend image from rebuilding.

Concurrency is `cancel-in-progress: false`: a half-finished deploy is worse
than a queued one.

## `deploy.yml`

Entry points: `workflow_call` (chained from build-and-push, dev) and
`workflow_dispatch` (manual, usually prod).

### Resolving which image to deploy

The subtle part. If only the frontend changed, no backend image was built for
this SHA. Passing an empty `backend_image` would make Terraform fall back to
its bootstrap placeholder and **take the real backend down**.

So for each app the workflow resolves, in order:

1. An image tagged with this commit SHA, if one exists in the registry.
2. Otherwise, the image the Cloud Run service is currently running, read back
   with `gcloud run services describe`.
3. Otherwise empty — a first deploy, where the placeholder is correct.

### Plan then apply

```bash
terraform plan -out=tfplan   # written to the job summary
terraform apply tfplan       # the same plan file, same job
```

Applying the saved plan means the change that runs is byte-for-byte the change
that was reviewed. Planning in one job and applying in another re-plans, and
the second plan can differ.

### The approval gate

```yaml
environment:
  name: ${{ inputs.environment }}
  url: ${{ steps.outputs.outputs.frontend_url }}
```

Add required reviewers to the `prod` GitHub Environment and no prod apply can
happen without sign-off. The `url` makes the deployed frontend a clickable
link on the run.

Note that the build job also references the environment (that is where the
GCP variables live), so a prod run requests approval twice: once before
building prod artifacts, once before applying them. If you prefer a single
gate, move the variables to repository level with an environment suffix and
keep `environment:` only on the terraform job.

### Smoke test

After apply, `/health` and `/api/health` are polled with retries. Terraform
reporting success only means the API calls succeeded; this checks the
application actually serves traffic.

## Adding a new environment

1. `cp -r infra/terraform/environments/dev infra/terraform/environments/staging`
2. Edit `main.tf` (`environment = "staging"`), `terraform.tfvars`, `backend.hcl`.
3. Add `staging` to the `stack` matrix in `ci.yml`.
4. Create a `staging` GitHub Environment with the same variables.
5. Add `staging` to the `environment` choice lists in `deploy.yml` and
   `build-and-push.yml`.

## Local verification

```bash
# workflow syntax + expression checking
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest

# the same checks CI runs
cd apps/frontend && npm ci && npm run typecheck && npm run lint && npm run build
cd apps/backend  && pip install -e ".[dev]" && ruff check . && pytest
cd infra/terraform && terraform fmt -check -recursive
```
