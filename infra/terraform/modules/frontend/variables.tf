variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Cloud Run region."
  type        = string
}

variable "environment" {
  description = "Environment name (dev | prod)."
  type        = string
}

variable "service_name" {
  description = "Cloud Run service name for the frontend."
  type        = string
}

variable "image" {
  description = "Frontend container image reference."
  type        = string
}

variable "release" {
  description = "Version stamp, normally the git SHA."
  type        = string
  default     = "unknown"
}

variable "backend_url" {
  description = "HTTPS URL of the backend service. Injected at runtime and read per request by the Next.js server, so the image does not need rebuilding when the backend URL changes."
  type        = string
}

variable "backend_service_name" {
  description = "Cloud Run service name of the backend. Used to grant this service permission to invoke it when the backend is not public."
  type        = string
  default     = null
}

variable "grant_backend_invoker" {
  description = "Grant the frontend's identity roles/run.invoker on the backend. Required when the backend has allow_public_access = false."
  type        = bool
  default     = false
}

# --- Sizing ------------------------------------------------------------------

variable "cpu" {
  description = "CPU per instance."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory per instance. Next.js SSR needs more headroom than the Python service."
  type        = string
  default     = "512Mi"
}

variable "min_instances" {
  description = "Minimum warm instances. Worth setting to 1 in prod: a Node cold start is user-visible on the first page load."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum instances."
  type        = number
  default     = 5
}

variable "max_concurrency" {
  description = "Concurrent requests per instance."
  type        = number
  default     = 80
}

variable "allow_public_access" {
  description = "Allow unauthenticated access. Must be true for a browser-facing app."
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
  default     = "/api/health"
}

variable "liveness_probe_path" {
  description = "HTTP path for the liveness probe, or null to disable it."
  type        = string
  default     = "/api/health"
}
