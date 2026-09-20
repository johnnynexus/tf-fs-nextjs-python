# -----------------------------------------------------------------------------
# Frontend service: the Next.js container on Cloud Run.
#
# DEPLOYMENT CHOICE - why a container, not S3/CloudFront or Vercel:
#
#   The app uses Server Components and a server-side proxy route, so it is not
#   a static site; `output: export` would drop both. That rules out a pure
#   object-storage/CDN deployment.
#
#   Running it on Cloud Run alongside the backend buys:
#     * One deployment model, one registry, one IAM model, one log sink for
#       both services - no second vendor, no second auth story in CI.
#     * BACKEND_INTERNAL_URL can be a *runtime* env var. On a static/edge
#       host the backend URL has to be baked in at build time, which creates a
#       circular dependency with Terraform (the URL does not exist until after
#       apply).
#     * Scale to zero, so an idle environment costs nothing.
#
#   The trade-off is no global edge cache for static assets. If that matters,
#   put Cloud CDN in front of this service via an external HTTPS load
#   balancer - additive, and it does not change anything below.
# -----------------------------------------------------------------------------

locals {
  env = {
    NODE_ENV    = "production"
    ENVIRONMENT = var.environment
    # Read per request by Server Components and by the /api/backend proxy.
    BACKEND_INTERNAL_URL = var.backend_url
    # NEXT_PUBLIC_* values are inlined at build time, so setting one here
    # would have no effect on the client bundle. It is listed only so the
    # frontend's own /api/health route can report a release.
    NEXT_PUBLIC_RELEASE = var.release
  }
}

module "service" {
  source = "../cloud_run_service"

  project_id   = var.project_id
  region       = var.region
  service_name = var.service_name
  image        = var.image

  # Matches the PORT default in the frontend Dockerfile's runner stage.
  container_port = 8080

  cpu             = var.cpu
  memory          = var.memory
  min_instances   = var.min_instances
  max_instances   = var.max_instances
  max_concurrency = var.max_concurrency

  env = local.env

  # The frontend only talks to the backend over the public internet, so it
  # needs no VPC attachment.
  vpc_access = null

  allow_public_access = var.allow_public_access
  deletion_protection = var.deletion_protection
  labels              = var.labels

  # This route reports only on the Next.js server, deliberately excluding the
  # backend, so a backend outage does not restart healthy frontend instances.
  startup_probe_path  = var.startup_probe_path
  liveness_probe_path = var.liveness_probe_path
}

# Only needed when the backend is private. With a public backend this is a
# no-op, and the frontend reaches it like any other HTTPS client.
resource "google_cloud_run_v2_service_iam_member" "backend_invoker" {
  count = var.grant_backend_invoker ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = var.backend_service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${module.service.service_account_email}"
}
