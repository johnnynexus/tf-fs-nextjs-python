variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Cloud Run region."
  type        = string
}

variable "service_name" {
  description = "Cloud Run service name. Must be unique per region and <= 49 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.service_name)) && length(var.service_name) <= 49
    error_message = "service_name must be lowercase alphanumeric with hyphens, start with a letter, and be at most 49 characters."
  }
}

variable "image" {
  description = "Fully-qualified container image reference, ideally digest-pinned (repo@sha256:...) so a revision is immutable."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on. Cloud Run injects this as $PORT."
  type        = number
  default     = 8080
}

# --- Sizing ------------------------------------------------------------------

variable "cpu" {
  description = "CPU allocation per instance, e.g. \"1\" or \"0.5\". Values below 1 cap max concurrency."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory per instance, e.g. \"512Mi\" or \"1Gi\"."
  type        = string
  default     = "512Mi"
}

variable "min_instances" {
  description = "Minimum instances kept warm. 0 means scale to zero (free when idle, but cold starts). Set to 1+ in prod to avoid cold-start latency."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Upper bound on instances. Acts as a cost ceiling as much as a scaling limit."
  type        = number
  default     = 5
}

variable "max_concurrency" {
  description = "Concurrent requests per instance. High values suit async I/O-bound services."
  type        = number
  default     = 80
}

variable "request_timeout_seconds" {
  description = "Per-request timeout."
  type        = number
  default     = 60
}

variable "cpu_idle" {
  description = "Throttle CPU when no request is being handled. true is much cheaper; set false only if the service does background work between requests."
  type        = bool
  default     = true
}

variable "startup_cpu_boost" {
  description = "Temporarily grant extra CPU during startup to shorten cold starts."
  type        = bool
  default     = true
}

# --- Configuration -----------------------------------------------------------

variable "env" {
  description = "Plain environment variables. Never put secrets here; they would be visible in the service definition and in Terraform state."
  type        = map(string)
  default     = {}
}

variable "secret_env" {
  description = "Environment variables sourced from Secret Manager. `secret_id` is the short secret name; `version` is usually \"latest\"."
  type = map(object({
    secret_id = string
    version   = optional(string, "latest")
  }))
  default = {}
}

# --- Networking and access ---------------------------------------------------

variable "allow_public_access" {
  description = "Grant roles/run.invoker to allUsers. Required for a browser-facing service. Some org policies (constraints/iam.allowedPolicyMemberDomains) block this."
  type        = bool
  default     = true
}

variable "ingress" {
  description = "Ingress setting: INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, or INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER",
    ], var.ingress)
    error_message = "ingress must be one of INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  }
}

variable "vpc_access" {
  description = "Attach the service to a VPC via direct egress. null disables VPC access entirely. Only needed to reach private resources such as Cloud SQL private IP."
  type = object({
    network_id = string
    subnet_id  = string
    # PRIVATE_RANGES_ONLY sends only RFC1918 traffic through the VPC, so
    # public API calls keep using the default (cheaper) path.
    egress = optional(string, "PRIVATE_RANGES_ONLY")
  })
  default = null
}

# --- Identity ----------------------------------------------------------------

variable "service_account_roles" {
  description = "Project-level IAM roles granted to this service's runtime identity. Keep this minimal."
  type        = list(string)
  default     = []
}

# --- Probes ------------------------------------------------------------------

variable "startup_probe_path" {
  description = "HTTP path for the startup probe. Cloud Run will not route traffic to a revision until this succeeds."
  type        = string
  default     = "/health"
}

variable "liveness_probe_path" {
  description = "HTTP path for the liveness probe. Set to null to disable; a failing liveness probe restarts the container."
  type        = string
  default     = "/health"
}

variable "startup_probe_failure_threshold" {
  description = "Consecutive startup probe failures tolerated before the revision is marked failed."
  type        = number
  default     = 10
}

# --- Metadata ----------------------------------------------------------------

variable "labels" {
  description = "Labels applied to the service."
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Block `terraform destroy` on this service. Should be true in prod."
  type        = bool
  default     = false
}

variable "depends_on_resources" {
  description = "Opaque values to force ordering against resources created outside this module (for example, a Secret Manager IAM binding that must exist before the service starts)."
  type        = list(string)
  default     = []
}
