# --- Identity ----------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "project_name" {
  description = "Short application name used as a prefix for every resource, e.g. \"tfs\". Keep it under ~12 characters: Cloud Run service names and service account IDs have length limits."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.project_name)) && length(var.project_name) <= 16
    error_message = "project_name must be lowercase alphanumeric with hyphens and at most 16 characters."
  }
}

variable "environment" {
  description = "Environment name. Becomes part of every resource name and of the ENVIRONMENT env var the apps read."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "region" {
  description = "Region for Cloud Run, Artifact Registry and Cloud SQL."
  type        = string
}

# --- Images ------------------------------------------------------------------

variable "backend_image" {
  description = "Backend image reference. Leave empty on the very first apply - the registry has no images yet, so a public placeholder is used and CI replaces it on the next deploy."
  type        = string
  default     = ""
}

variable "frontend_image" {
  description = "Frontend image reference. Same first-apply behaviour as backend_image."
  type        = string
  default     = ""
}

variable "release" {
  description = "Version stamp for both services, normally the git SHA. Surfaced by the health endpoints."
  type        = string
  default     = "unknown"
}

# --- Networking --------------------------------------------------------------

variable "subnet_cidr" {
  description = "CIDR for the application subnet."
  type        = string
  default     = "10.10.0.0/24"
}

# --- Database ----------------------------------------------------------------

variable "enable_database" {
  description = "Provision Cloud SQL Postgres. Defaults to false: Cloud SQL has no free tier and costs about $8/month at the smallest tier even when idle, while the backend is built to run without it."
  type        = bool
  default     = false
}

variable "database_tier" {
  description = "Cloud SQL machine type."
  type        = string
  default     = "db-f1-micro"
}

variable "database_availability_type" {
  description = "ZONAL or REGIONAL (HA)."
  type        = string
  default     = "ZONAL"
}

variable "database_disk_size_gb" {
  description = "Cloud SQL disk size in GB."
  type        = number
  default     = 10
}

variable "database_backup_enabled" {
  description = "Enable automated backups."
  type        = bool
  default     = true
}

variable "database_point_in_time_recovery" {
  description = "Enable point-in-time recovery."
  type        = bool
  default     = false
}

variable "database_deletion_protection" {
  description = "Protect the Cloud SQL instance from deletion."
  type        = bool
  default     = true
}

# --- Service sizing ----------------------------------------------------------

variable "backend_cpu" {
  description = "Backend CPU per instance."
  type        = string
  default     = "1"
}

variable "backend_memory" {
  description = "Backend memory per instance."
  type        = string
  default     = "512Mi"
}

variable "backend_min_instances" {
  description = "Backend minimum warm instances (0 = scale to zero)."
  type        = number
  default     = 0
}

variable "backend_max_instances" {
  description = "Backend maximum instances - the cost ceiling."
  type        = number
  default     = 5
}

variable "frontend_cpu" {
  description = "Frontend CPU per instance."
  type        = string
  default     = "1"
}

variable "frontend_memory" {
  description = "Frontend memory per instance."
  type        = string
  default     = "512Mi"
}

variable "frontend_min_instances" {
  description = "Frontend minimum warm instances."
  type        = number
  default     = 0
}

variable "frontend_max_instances" {
  description = "Frontend maximum instances."
  type        = number
  default     = 5
}

# --- Access ------------------------------------------------------------------

variable "backend_public" {
  description = "Allow unauthenticated access to the backend. Set false to lock it down so only the frontend's service identity can invoke it; the frontend proxy keeps working, direct browser calls stop."
  type        = bool
  default     = true
}

variable "additional_cors_origins" {
  description = <<-EOT
    Extra browser origins allowed to call the backend directly.

    There is deliberately no automatic entry for the frontend's own Cloud Run
    URL, because that would be a dependency cycle: the backend would need the
    frontend's URL, and the frontend needs the backend's. The cycle does not
    need breaking, because the browser reaches the backend through the
    frontend's same-origin /api/backend proxy by default.

    Add an origin here only if you build the frontend image with
    NEXT_PUBLIC_API_BASE_URL set (direct cross-origin calls), or if another
    client - a local dev server, a mobile web app - calls the API directly.
  EOT
  type        = list(string)
  default     = []
}

variable "log_level" {
  description = "Backend log level."
  type        = string
  default     = "INFO"
}

variable "service_deletion_protection" {
  description = "Block `terraform destroy` on the Cloud Run services."
  type        = bool
  default     = false
}

variable "extra_labels" {
  description = "Additional labels merged into the standard set."
  type        = map(string)
  default     = {}
}
