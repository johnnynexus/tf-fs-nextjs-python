# -----------------------------------------------------------------------------
# Backend service: the FastAPI container on Cloud Run.
#
# This module owns everything backend-specific - its env contract, database
# wiring and IAM - and delegates the generic Cloud Run mechanics to
# modules/cloud_run_service.
# -----------------------------------------------------------------------------

locals {
  database_enabled = var.database != null

  # The env contract the backend expects. Kept here rather than in the
  # environment stacks so adding a setting means editing one file.
  env = {
    ENVIRONMENT = var.environment
    RELEASE     = var.release
    LOG_LEVEL   = var.log_level
    # Comma-separated: app/core/config.py splits on commas.
    CORS_ORIGINS = join(",", var.cors_origins)
    # Single worker per instance: Cloud Run scales by adding instances, so a
    # second worker only competes for the same CPU allocation.
    WEB_CONCURRENCY = "1"
  }

  # Mounted by reference from Secret Manager, never as a plain env value.
  secret_env = local.database_enabled ? {
    DATABASE_URL = {
      secret_id = var.database.url_secret_id
      version   = "latest"
    }
  } : {}
}

# The runtime identity needs permission to read the connection-string secret.
# Scoped to this one secret rather than granted at project level.
resource "google_secret_manager_secret_iam_member" "database_url_accessor" {
  count = local.database_enabled ? 1 : 0

  project   = var.project_id
  secret_id = var.database.url_secret_name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.service.service_account_email}"
}

module "service" {
  source = "../cloud_run_service"

  project_id   = var.project_id
  region       = var.region
  service_name = var.service_name
  image        = var.image

  # The Dockerfile's uvicorn command binds to $PORT, which Cloud Run sets
  # from this value.
  container_port = 8080

  cpu             = var.cpu
  memory          = var.memory
  min_instances   = var.min_instances
  max_instances   = var.max_instances
  max_concurrency = var.max_concurrency

  env        = local.env
  secret_env = local.secret_env

  # Only attach to the VPC when there is a private-IP database to reach.
  vpc_access = local.database_enabled ? var.vpc_access : null

  # roles/cloudsql.client is what allows the runtime identity to open a
  # connection to the instance.
  service_account_roles = local.database_enabled ? ["roles/cloudsql.client"] : []

  allow_public_access = var.allow_public_access
  deletion_protection = var.deletion_protection
  labels              = var.labels

  # Liveness hits /health (no I/O) rather than /health/ready, so a database
  # outage degrades responses instead of triggering container restarts.
  startup_probe_path  = var.startup_probe_path
  liveness_probe_path = var.liveness_probe_path

  # Forces the IAM binding above to exist before the service tries to read
  # the secret, which otherwise fails the first revision.
  depends_on_resources = [
    for binding in google_secret_manager_secret_iam_member.database_url_accessor : binding.etag
  ]
}
