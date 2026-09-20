variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for the Cloud SQL instance."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names, e.g. \"myapp-dev\"."
  type        = string
}

variable "network_id" {
  description = "VPC the instance attaches to for private IP."
  type        = string
}

variable "private_service_connection_id" {
  description = "ID of the service networking peering from the networking module. Passed purely to force correct ordering: a private-IP instance cannot be created before the peering exists."
  type        = string
}

variable "database_version" {
  description = "Cloud SQL Postgres version."
  type        = string
  default     = "POSTGRES_16"
}

variable "tier" {
  description = "Machine type. db-f1-micro is the cheapest (shared core, ~$8/month); use db-custom-* in prod."
  type        = string
  default     = "db-f1-micro"
}

variable "availability_type" {
  description = "ZONAL (single zone, cheaper) or REGIONAL (HA failover, roughly double the cost)."
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "availability_type must be ZONAL or REGIONAL."
  }
}

variable "disk_size_gb" {
  description = "Initial disk size. Autoresize is enabled, so this is a floor rather than a cap."
  type        = number
  default     = 10
}

variable "database_name" {
  description = "Name of the application database created on the instance."
  type        = string
  default     = "app"
}

variable "database_user" {
  description = "Application database user. The password is generated and stored in Secret Manager; it is never written to a tfvars file."
  type        = string
  default     = "app"
}

variable "backup_enabled" {
  description = "Enable automated daily backups."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of automated backups retained."
  type        = number
  default     = 7
}

variable "point_in_time_recovery" {
  description = "Enable write-ahead log archiving for point-in-time recovery. Adds storage cost; worth it in prod."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Protect the instance from deletion. Must be false before `terraform destroy` will succeed."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to the instance and secret."
  type        = map(string)
  default     = {}
}
