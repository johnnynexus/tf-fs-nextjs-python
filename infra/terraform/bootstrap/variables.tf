variable "project_id" {
  description = "GCP project that will hold the Terraform state bucket and the Workload Identity Federation pool."
  type        = string
}

variable "region" {
  description = "Region for the state bucket. Keep it near the deployment region."
  type        = string
  default     = "us-west1"
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket, e.g. \"acme-tfs-tfstate\"."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to authenticate, as \"owner/repo\". This is the security boundary: only workflows in this repository can assume the deployer identity."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in owner/repo form."
  }
}

variable "pool_id" {
  description = "Workload Identity Pool ID. Cannot be reused for 30 days after deletion, so change it if you need to recreate quickly."
  type        = string
  default     = "github-pool"
}

variable "provider_id" {
  description = "Workload Identity Provider ID within the pool."
  type        = string
}

variable "deployer_account_id" {
  description = "Service account ID that GitHub Actions impersonates."
  type        = string
  default     = "github-deployer"
}

variable "deployer_roles" {
  description = <<-EOT
    Project roles granted to the CI deployer.

    These are broad because Terraform creates service accounts, IAM bindings,
    networks and Cloud Run services. Narrow them for a real production
    project - ideally by splitting into a plan-only reader identity and an
    apply identity, and by scoping bindings to specific resources rather than
    the whole project.
  EOT
  type        = list(string)
  default = [
    "roles/run.admin",                       # manage Cloud Run services
    "roles/artifactregistry.admin",          # manage and push to the registry
    "roles/iam.serviceAccountAdmin",         # create per-service identities
    "roles/iam.serviceAccountUser",          # deploy services as those identities
    "roles/resourcemanager.projectIamAdmin", # grant roles to those identities
    "roles/compute.networkAdmin",            # VPC and subnets
    "roles/servicenetworking.networksAdmin", # Cloud SQL private services access
    "roles/cloudsql.admin",                  # Cloud SQL instances
    "roles/secretmanager.admin",             # connection-string secret
    "roles/serviceusage.serviceUsageAdmin",  # enable required APIs
  ]
}

variable "enable_required_apis" {
  description = "Let Terraform enable the APIs this stack needs. Set false if APIs are managed centrally in your organisation."
  type        = bool
  default     = true
}

variable "state_bucket_retention_days" {
  description = "How long non-current state object versions are retained before deletion."
  type        = number
  default     = 90
}

variable "labels" {
  description = "Labels applied to created resources."
  type        = map(string)
  default     = {}
}
