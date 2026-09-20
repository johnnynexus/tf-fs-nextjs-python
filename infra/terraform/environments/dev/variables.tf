# Inputs for this environment. Values come from terraform.tfvars, except for
# the image references and release, which CI passes with -var so a deploy can
# pin the exact commit being shipped.

variable "project_id" {
  description = "GCP project ID for this environment."
  type        = string
}

variable "project_name" {
  description = "Short application name, used as a resource name prefix."
  type        = string
}

variable "region" {
  description = "Deployment region."
  type        = string
}

variable "backend_image" {
  description = "Backend image reference. Empty on the first apply; CI supplies a digest-pinned reference thereafter."
  type        = string
  default     = ""
}

variable "frontend_image" {
  description = "Frontend image reference. Empty on the first apply."
  type        = string
  default     = ""
}

variable "release" {
  description = "Git SHA or version being deployed."
  type        = string
  default     = "unknown"
}

variable "subnet_cidr" {
  description = "CIDR for the application subnet."
  type        = string
  default     = "10.10.0.0/24"
}

# --- Database ----------------------------------------------------------------

variable "enable_database" {
  description = "Provision Cloud SQL Postgres for this environment."
  type        = bool
  default     = false
}

variable "database_tier" {
  description = "Cloud SQL machine type."
  type        = string
  default     = "db-f1-micro"
}

variable "database_availability_type" {
  description = "ZONAL or REGIONAL."
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

# --- Sizing ------------------------------------------------------------------

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
  description = "Backend minimum warm instances."
  type        = number
  default     = 0
}

variable "backend_max_instances" {
  description = "Backend maximum instances."
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

# --- Access and misc ----------------------------------------------------------

variable "backend_public" {
  description = "Allow unauthenticated access to the backend."
  type        = bool
  default     = true
}

variable "additional_cors_origins" {
  description = "Extra browser origins permitted to call the backend directly."
  type        = list(string)
  default     = []
}

variable "log_level" {
  description = "Backend log level."
  type        = string
  default     = "INFO"
}

variable "service_deletion_protection" {
  description = "Block destroy on the Cloud Run services."
  type        = bool
  default     = false
}
