# -----------------------------------------------------------------------------
# prod environment values.
#
# Committed on purpose: no secrets here. See dev/terraform.tfvars for the
# reasoning.
#
# Currently shares the dev project (a personal sandbox), which is fine for a
# reference implementation: resource names are prefixed tfs-prod-* and the
# state lives under its own prefix.
#
# For anything real, move this to a separate project - it is the only hard
# isolation boundary GCP offers for quota, IAM and billing. Doing so means a
# second bootstrap run and updating this file plus backend.hcl and the prod
# GitHub Environment variables.
# -----------------------------------------------------------------------------

project_id   = "nexus-gcloud-sandbox"
project_name = "tfs"
region       = "us-west1"

# Distinct from dev's range, so the two VPCs could be peered later without a
# CIDR collision.
subnet_cidr = "10.20.0.0/24"

# --- Cost/latency posture ----------------------------------------------------
# One warm instance each: prod pays ~$10-15/month per service to remove
# cold starts from the user-visible path. Drop to 0 if occasional 1-3s first
# requests are acceptable.
backend_min_instances  = 1
backend_max_instances  = 20
frontend_min_instances = 1
frontend_max_instances = 20

backend_cpu     = "1"
backend_memory  = "1Gi"
frontend_cpu    = "1"
frontend_memory = "1Gi"

# --- Database ----------------------------------------------------------------
# Still off by default so a first prod apply is free and fast. Flip to true
# when you actually need persistence, and prefer REGIONAL for HA.
enable_database                 = false
database_tier                   = "db-custom-1-3840"
database_availability_type      = "ZONAL"
database_disk_size_gb           = 20
database_backup_enabled         = true
database_point_in_time_recovery = true
database_deletion_protection    = true

# --- Access ------------------------------------------------------------------
backend_public = true

# No localhost here: nothing on a laptop should be calling prod directly.
additional_cors_origins = []

log_level = "INFO"

# Guards against an accidental `terraform destroy` against prod.
service_deletion_protection = true
