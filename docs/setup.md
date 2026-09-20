# Setup

Two paths: local development (Docker only), and a full cloud deployment.

## Local development

### Prerequisites

- Docker Desktop (includes Compose v2)
- Git

That is the complete list. Node and Python are only needed to run an app
outside its container.

### Steps

```bash
git clone <this-repo>
cd tf-fs-nextjs-python
docker compose up --build
```

First build takes a few minutes; subsequent starts are seconds.

Verify:

```bash
curl localhost:8000/health
curl localhost:8000/health/ready
curl "localhost:8000/api/v1/hello?name=you"
curl localhost:3000/api/health
curl "localhost:3000/api/backend/hello?name=viaproxy"   # through the proxy
```

Then open http://localhost:3000. Both cards should read **connected**.

Because docker-compose sets `DATABASE_URL`, the database-backed routes work
locally too:

```bash
curl -X POST localhost:3000/api/backend/items \
  -H 'content-type: application/json' \
  -d '{"name":"widget","description":"created through the proxy"}'
curl localhost:3000/api/backend/items
```

### Port conflicts

```bash
cp .env.example .env
# edit POSTGRES_HOST_PORT / BACKEND_HOST_PORT / FRONTEND_HOST_PORT
docker compose up
```

### Useful commands

```bash
docker compose logs -f backend      # follow one service
docker compose restart frontend
docker compose down                 # stop, keep data
docker compose down -v              # stop, wipe the database volume
docker compose build --no-cache     # after a dependency change
```

## Cloud deployment

### Prerequisites

- A GCP project with billing enabled — ideally one per environment
- `gcloud` CLI: `gcloud auth application-default login`
- Terraform >= 1.6
- Enough permission to create service accounts and IAM bindings
  (`roles/owner` is simplest for the one-off bootstrap)

### 1. Bootstrap

Creates the Terraform state bucket and GitHub OIDC federation.

```bash
cd infra/terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_id        = "my-project-dev"
region            = "us-west1"
state_bucket_name = "my-org-tfs-tfstate"      # globally unique
github_repository = "my-org/tf-fs-nextjs-python"
pool_id           = "github-pool"
provider_id       = "github-provider"
```

```bash
terraform init
terraform apply
terraform output github_configuration_summary
```

### 2. Configure GitHub

Settings → Environments → create `dev` and `prod`. Add **required reviewers**
to `prod`. In each environment, add these **variables** (none are secret):

```
GCP_PROJECT_ID                  = my-project-dev
GCP_REGION                      = us-west1
GCP_WORKLOAD_IDENTITY_PROVIDER  = <bootstrap output>
GCP_SERVICE_ACCOUNT             = <bootstrap output>
TF_STATE_BUCKET                 = <bootstrap output>
TF_PROJECT_NAME                 = tfs
```

`TF_PROJECT_NAME` must match `project_name` in that environment's
`terraform.tfvars`, because the registry repository is named
`<project_name>-<environment>`.

### 3. Deploy an environment

```bash
cd infra/terraform/environments/dev
```

Edit `backend.hcl` — set `bucket` to the bootstrap's `state_bucket_name`.
Edit `terraform.tfvars` — set `project_id`.

```bash
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
terraform output
```

The first apply deploys a placeholder image; that is expected and explained in
[`infra/terraform/README.md`](../infra/terraform/README.md).

### 4. Ship real images

Merge to `main` and CI builds, pushes and deploys to dev automatically. To do
it by hand, see step 3 of the Terraform README.

### 5. Promote to prod

GitHub → Actions → **Deploy** → Run workflow → environment `prod`. A required
reviewer must approve before the apply runs.

## Verifying a fresh clone

```bash
git clone <repo> /tmp/verify && cd /tmp/verify

docker compose up --build -d --wait
curl -fsS localhost:8000/health && echo OK
curl -fsS localhost:3000/api/health && echo OK
docker compose down -v

cd infra/terraform
terraform fmt -check -recursive
(cd environments/dev && terraform init -backend=false && terraform validate)
(cd environments/prod && terraform init -backend=false && terraform validate)
(cd bootstrap && terraform init -backend=false && terraform validate)
```
