variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Cloud Run region."
  type        = string
}

variable "environment" {
  description = "Environment name (dev | prod). Passed to the app as ENVIRONMENT."
  type        = string
}

variable "service_name" {
  description = "Cloud Run service name for the backend."
  type        = string
}

variable "image" {
  description = "Backend container image reference."
  type        = string
}

variable "release" {
  description = "Version stamp surfaced by /health, normally the git SHA."
  type        = string
  default     = "unknown"
}

variable "cors_origins" {
  description = "Browser origins allowed to call this API directly. Empty when the frontend proxies all browser traffic through its own origin."
  type        = list(string)
  default     = []
}

variable "log_level" {
  description = "Python log level."
  type        = string
  default     = "INFO"
}

# --- Sizing ------------------------------------------------------------------

variable "cpu" {
  description = "CPU per instance."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory per instance."
  type        = string
  default     = "512Mi"
}

variable "min_instances" {
  description = "Minimum warm instances."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum instances."
  type        = number
  default     = 5
}

variable "max_concurrency" {
  description = "Concurrent requests per instance. FastAPI is async and I/O-bound, so a high value is appropriate."
  type        = number
  default     = 80
}

# --- Database ----------------------------------------------------------------

variable "database" {
  description = "Database wiring. null when the deployment has no database, in which case DATABASE_URL is simply not set and the app runs in its no-database mode."
  type = object({
    url_secret_id   = string
    url_secret_name = string
    connection_name = string
  })
  default = null
}

variable "vpc_access" {
  description = "VPC attachment, required to reach Cloud SQL over private IP. null when there is no database."
  type = object({
    network_id = string
    subnet_id  = string
  })
  default = null
}

# --- Misc --------------------------------------------------------------------

variable "allow_public_access" {
  description = "Allow unauthenticated invocation. Needed if the browser calls the backend directly; can be false when all traffic goes through the frontend proxy and the frontend's identity is granted run.invoker."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Block destroy of the Cloud Run service."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels applied to the service."
  type        = map(string)
  default     = {}
}

variable "startup_probe_path" {
  description = "HTTP path for the startup probe. Overridden to \"/\" while the bootstrap placeholder image is deployed, since that image does not serve the real health route."
  type        = string
  default     = "/health"
}

variable "liveness_probe_path" {
  description = "HTTP path for the liveness probe, or null to disable it."
  type        = string
  default     = "/health"
}
