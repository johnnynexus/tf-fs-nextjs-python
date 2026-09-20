# =============================================================================
# Environment: dev
#
#   terraform init -backend-config=backend.hcl
#   terraform plan
#   terraform apply
#
# Everything here is thin on purpose: the module wiring lives in
# modules/stack, so dev and prod cannot drift apart structurally. What differs
# between environments is the *values* below and in terraform.tfvars.
#
# Dev is tuned for cost: both services scale to zero and the database is off.
# An idle dev environment bills essentially nothing.
# =============================================================================

module "stack" {
  source = "../../modules/stack"

  project_id   = var.project_id
  project_name = var.project_name
  environment  = "dev"
  region       = var.region

  backend_image  = var.backend_image
  frontend_image = var.frontend_image
  release        = var.release

  subnet_cidr = var.subnet_cidr

  enable_database                 = var.enable_database
  database_tier                   = var.database_tier
  database_availability_type      = var.database_availability_type
  database_disk_size_gb           = var.database_disk_size_gb
  database_backup_enabled         = var.database_backup_enabled
  database_point_in_time_recovery = var.database_point_in_time_recovery
  database_deletion_protection    = var.database_deletion_protection

  backend_cpu            = var.backend_cpu
  backend_memory         = var.backend_memory
  backend_min_instances  = var.backend_min_instances
  backend_max_instances  = var.backend_max_instances
  frontend_cpu           = var.frontend_cpu
  frontend_memory        = var.frontend_memory
  frontend_min_instances = var.frontend_min_instances
  frontend_max_instances = var.frontend_max_instances

  backend_public              = var.backend_public
  additional_cors_origins     = var.additional_cors_origins
  log_level                   = var.log_level
  service_deletion_protection = var.service_deletion_protection
}
