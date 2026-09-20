# -----------------------------------------------------------------------------
# Stack composition.
#
# This module wires the building blocks together. Both environment directories
# call it, so the wiring lives in exactly one place and `environments/dev` and
# `environments/prod` differ only in the values they pass - which is the whole
# point of having environments.
#
# Resource graph:
#
#   registry  ──────────────────────────────► (images pushed by CI)
#   networking ──► database (optional) ──► backend ──► frontend
#
# -----------------------------------------------------------------------------

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  labels = merge(
    {
      application = var.project_name
      environment = var.environment
      managed-by  = "terraform"
    },
    var.extra_labels,
  )

  # First-apply bootstrap: the Artifact Registry repository is created by this
  # same stack, so on a brand-new environment there is no image to deploy yet.
  # Google's public "hello" container stands in until CI pushes real images
  # and passes them via -var. Without this, the first apply would fail on an
  # image-not-found error and the registry would never get created.
  placeholder_image = "us-docker.pkg.dev/cloudrun/container/hello"

  backend_on_placeholder  = var.backend_image == ""
  frontend_on_placeholder = var.frontend_image == ""

  backend_image  = local.backend_on_placeholder ? local.placeholder_image : var.backend_image
  frontend_image = local.frontend_on_placeholder ? local.placeholder_image : var.frontend_image

  # The placeholder image serves "/" but not the real health routes, so probes
  # are relaxed while it is deployed. Without this the first apply fails: the
  # startup probe never succeeds and the revision is rejected.
  using_placeholder = local.backend_on_placeholder || local.frontend_on_placeholder
}

# --- Container registry ------------------------------------------------------

module "registry" {
  source = "../registry"

  project_id    = var.project_id
  region        = var.region
  repository_id = local.name_prefix
  labels        = local.labels
}

# --- Networking --------------------------------------------------------------

module "networking" {
  source = "../networking"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix
  subnet_cidr = var.subnet_cidr

  # The VPC peering is only required for Cloud SQL private IP, so it is
  # created only when the database is.
  enable_private_service_access = var.enable_database
}

# --- Database (optional) -----------------------------------------------------

module "database" {
  source = "../database"
  count  = var.enable_database ? 1 : 0

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix

  network_id                    = module.networking.network_id
  private_service_connection_id = module.networking.private_service_connection_id

  tier                   = var.database_tier
  availability_type      = var.database_availability_type
  disk_size_gb           = var.database_disk_size_gb
  backup_enabled         = var.database_backup_enabled
  point_in_time_recovery = var.database_point_in_time_recovery
  deletion_protection    = var.database_deletion_protection
  labels                 = local.labels
}

# --- Backend -----------------------------------------------------------------

module "backend" {
  source = "../backend"

  project_id   = var.project_id
  region       = var.region
  environment  = var.environment
  service_name = "${local.name_prefix}-backend"
  image        = local.backend_image
  release      = var.release
  log_level    = var.log_level

  cors_origins = var.additional_cors_origins

  cpu           = var.backend_cpu
  memory        = var.backend_memory
  min_instances = var.backend_min_instances
  max_instances = var.backend_max_instances

  # Passing the whole object (or null) keeps the "is there a database?"
  # decision in one place instead of spreading conditionals downstream.
  database = var.enable_database ? {
    url_secret_id   = module.database[0].database_url_secret_id
    url_secret_name = module.database[0].database_url_secret_name
    connection_name = module.database[0].connection_name
  } : null

  vpc_access = var.enable_database ? {
    network_id = module.networking.network_id
    subnet_id  = module.networking.subnet_id
  } : null

  allow_public_access = var.backend_public
  deletion_protection = var.service_deletion_protection
  labels              = local.labels

  startup_probe_path  = local.backend_on_placeholder ? "/" : "/health"
  liveness_probe_path = local.backend_on_placeholder ? null : "/health"
}

# --- Frontend ----------------------------------------------------------------

module "frontend" {
  source = "../frontend"

  project_id   = var.project_id
  region       = var.region
  environment  = var.environment
  service_name = "${local.name_prefix}-frontend"
  image        = local.frontend_image
  release      = var.release

  # Resolved after the backend is created, and injected as a runtime env var -
  # which is exactly why the frontend image does not need rebuilding when the
  # backend URL changes.
  backend_url = module.backend.url

  # When the backend is private, the frontend's identity needs explicit
  # permission to call it.
  backend_service_name  = module.backend.name
  grant_backend_invoker = !var.backend_public

  cpu           = var.frontend_cpu
  memory        = var.frontend_memory
  min_instances = var.frontend_min_instances
  max_instances = var.frontend_max_instances

  # The frontend must always be reachable from a browser.
  allow_public_access = true
  deletion_protection = var.service_deletion_protection
  labels              = local.labels

  startup_probe_path  = local.frontend_on_placeholder ? "/" : "/api/health"
  liveness_probe_path = local.frontend_on_placeholder ? null : "/api/health"
}
