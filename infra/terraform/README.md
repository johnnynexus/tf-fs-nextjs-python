# Terraform - GCP (Cloud Run)

Infrastructure for the frontend, backend, container registry, networking and
an optional Postgres database.

## Layout

```
infra/terraform/
├── bootstrap/            Run once per project. Creates the state bucket and
│                         GitHub OIDC federation. Keeps state locally.
├── modules/
│   ├── cloud_run_service/  Generic Cloud Run v2 service (identity, probes,
│   │                       scaling, secrets, VPC). Shared base.
│   ├── frontend/           Next.js specifics on top of cloud_run_service
│   ├── backend/            FastAPI specifics + database wiring
│   ├── networking/         VPC, subnet, optional Cloud SQL peering
│   ├── database/           Optional Cloud SQL Postgres + Secret Manager
│   ├── registry/           Artifact Registry with cleanup policies
│   └── stack/              Composes all of the above. The single place the
│                           wiring lives.
└── environments/
    ├── dev/              Thin: calls modules/stack + its own tfvars
    └── prod/
```

`environments/*` are deliberately thin. All module wiring is in
`modules/stack`, so dev and prod cannot drift apart structurally — they differ
only in the values in their `terraform.tfvars`.

## Design decisions

**Cloud Run for both services.** The frontend is not a static site — it uses
Server Components and a server-side proxy route — so S3/CloudFront-style
hosting is out. Running both services on the same platform means one registry,
one IAM model, one log sink, and one auth story in CI. Both scale to zero, so
an idle environment costs essentially nothing. The trade-off is no global edge
cache; add Cloud CDN behind an external HTTPS load balancer if that matters.

**GCS remote state, no lock table.** GCS provides native state locking on the
state object, so the S3 + DynamoDB pairing has no equivalent here. Object
versioning is enabled as the recovery path.

**Directories, not workspaces, for environments.** Workspaces share one
backend config and one set of code paths, which makes "prod is slightly
different" awkward and makes a wrong-workspace apply easy. Separate
directories make the target explicit and let each environment pin its own
backend bucket and provider config.

**Direct VPC egress, not a Serverless VPC Connector.** A connector runs a
managed instance group costing ~$9/month even when idle. Direct egress has no
standing cost.

**Database off by default.** Cloud SQL has no free tier (~$8/month minimum,
billed idle). The backend is written to run without it, so `enable_database`
defaults to `false` and turning it on is a one-line tfvars change.

## Prerequisites

- Terraform >= 1.6
- `gcloud` CLI, authenticated: `gcloud auth application-default login`
- A GCP project with billing enabled (one per environment is recommended)
- Project-level permission to create service accounts and IAM bindings
  (`roles/owner` is simplest for the bootstrap)

## 1. Bootstrap (once per project)

Creates the Terraform state bucket and the Workload Identity Federation setup
that lets GitHub Actions authenticate without any stored key.

```bash
cd infra/terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit: project_id, state_bucket_name (globally unique), github_repository

terraform init
terraform plan
terraform apply
```

Then copy the outputs into GitHub and into the environment backend configs:

```bash
terraform output github_configuration_summary
terraform output -raw state_bucket_name
```

Put the bucket name in `environments/dev/backend.hcl` and
`environments/prod/backend.hcl` (replacing `REPLACE_ME-tfstate`).

## 2. Deploy an environment

```bash
cd infra/terraform/environments/dev

# Edit terraform.tfvars: set project_id to your GCP project.

terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

The **first apply deploys a placeholder image** (`cloudrun/container/hello`),
because the Artifact Registry repository is created by this same stack and has
no images yet. That is expected — the apply succeeds and gives you a registry
to push to. The `using_placeholder_image` output is `true` until real images
are deployed.

## 3. Push real images and redeploy

CI does this automatically on merge to main. Manually:

```bash
cd infra/terraform/environments/dev
REGISTRY=$(terraform output -raw registry_url)
gcloud auth configure-docker "${REGISTRY%%/*}" --quiet

TAG=$(git rev-parse HEAD)
docker build -t "$REGISTRY/backend:$TAG"  --build-arg RELEASE="$TAG" ../../../../apps/backend
docker build -t "$REGISTRY/frontend:$TAG" --build-arg NEXT_PUBLIC_RELEASE="$TAG" ../../../../apps/frontend
docker push "$REGISTRY/backend:$TAG"
docker push "$REGISTRY/frontend:$TAG"

terraform apply \
  -var="backend_image=$REGISTRY/backend:$TAG" \
  -var="frontend_image=$REGISTRY/frontend:$TAG" \
  -var="release=$TAG"
```

Then:

```bash
terraform output frontend_url
terraform output backend_url
```

## 4. Enabling the database

```bash
# in environments/<env>/terraform.tfvars
enable_database = true
```

```bash
terraform apply
```

This adds the VPC peering, a Cloud SQL instance, a generated password in
Secret Manager, and attaches the backend to the VPC. Allow ~10 minutes. The
backend picks up `DATABASE_URL` from Secret Manager automatically and
`/health/ready` flips from `"database": "disabled"` to `"ok"`.

To connect from a laptop (the instance has no public IP):

```bash
gcloud sql connect "$(terraform output -raw database_connection_name)" --user=app
```

## 5. Destroy

```bash
cd infra/terraform/environments/dev
terraform destroy
```

Gotchas, in the order you will hit them:

1. **Deletion protection.** Prod sets `service_deletion_protection = true` and
   `database_deletion_protection = true`. Set both to `false`, `terraform
   apply`, then destroy.
2. **Artifact Registry is not empty.** Delete the images first:
   `gcloud artifacts docker images delete --delete-tags "$REGISTRY/backend"`.
3. **The bootstrap stack is not destroyed by this.** It holds the state
   bucket, which has `force_destroy = false` on purpose — destroying it would
   take every environment's state with it.

## Common commands

```bash
terraform fmt -recursive                    # format everything
terraform fmt -check -recursive -diff       # what CI runs
terraform validate                          # after an init
terraform init -backend=false               # validate without credentials
terraform plan -out=tfplan && terraform apply tfplan
terraform output
```

## Variables worth knowing

| Variable                      | Default        | Notes                                             |
| ----------------------------- | -------------- | ------------------------------------------------- |
| `project_id`                  | —              | Required. Your GCP project.                        |
| `project_name`                | `tfs`          | Resource name prefix. Must match `TF_PROJECT_NAME` in CI. |
| `region`                      | `us-west1`     | Cloud Run, registry and Cloud SQL region.          |
| `enable_database`             | `false`        | Provision Cloud SQL.                               |
| `backend_min_instances`       | `0`            | `0` = scale to zero. `1+` removes cold starts.     |
| `backend_public`              | `true`         | `false` locks the API to the frontend's identity.  |
| `additional_cors_origins`     | `[]`           | Extra origins for direct browser calls.            |
| `service_deletion_protection` | `false`        | `true` in prod.                                    |

No value is hardcoded in the modules: region, sizing, names and toggles are
all variables, set per environment in `terraform.tfvars`.
