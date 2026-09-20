# =============================================================================
# Bootstrap - run once per project, before anything in environments/.
#
# Creates the two things the main stacks assume already exist:
#
#   1. The GCS bucket holding remote Terraform state.
#   2. Workload Identity Federation, so GitHub Actions can authenticate to GCP
#      with a short-lived OIDC token instead of a downloaded service account
#      key. No long-lived credential is ever created, stored or rotated.
#
# Run it with your own credentials:
#
#   gcloud auth application-default login
#   terraform init
#   terraform apply -var-file=terraform.tfvars
#
# State stays local here - see versions.tf for why.
# =============================================================================

locals {
  required_apis = [
    "iamcredentials.googleapis.com", # OIDC token exchange
    "iam.googleapis.com",            # service accounts
    "cloudresourcemanager.googleapis.com",
    "sts.googleapis.com",               # Security Token Service for WIF
    "run.googleapis.com",               # Cloud Run
    "artifactregistry.googleapis.com",  # image registry
    "compute.googleapis.com",           # VPC and subnets
    "secretmanager.googleapis.com",     # secrets
    "sqladmin.googleapis.com",          # Cloud SQL
    "servicenetworking.googleapis.com", # Cloud SQL private IP peering
  ]
}

resource "google_project_service" "required" {
  for_each = var.enable_required_apis ? toset(local.required_apis) : toset([])

  project = var.project_id
  service = each.value

  # Leave APIs enabled if this stack is destroyed; disabling them would break
  # unrelated resources in the project.
  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# Terraform state bucket
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "state" {
  project  = var.project_id
  name     = var.state_bucket_name
  location = var.region
  labels   = var.labels

  # State contains generated secrets (the Cloud SQL password, for one), so
  # this bucket is sensitive. Uniform access removes per-object ACLs, leaving
  # IAM as the single, auditable access mechanism.
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Versioning is the recovery path for a corrupted or truncated state file.
  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age        = var.state_bucket_retention_days
      with_state = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # Guards against `terraform destroy` wiping the state of every environment.
  force_destroy = false

  depends_on = [google_project_service.required]
}

# -----------------------------------------------------------------------------
# Workload Identity Federation for GitHub Actions
#
# Trust chain:
#   GitHub issues an OIDC token for a workflow run
#     -> the provider below validates the issuer and the attribute condition
#       -> STS exchanges it for a short-lived Google credential
#         -> that credential impersonates the deployer service account
#
# The attribute_condition is the security boundary. Without it, *any* GitHub
# repository on the internet could mint tokens accepted by this pool.
# -----------------------------------------------------------------------------

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions"
  description               = "Federated identity pool for GitHub Actions OIDC"

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Restricts the pool to one repository. GCP requires a condition on GitHub
  # providers precisely to prevent the "any repo can authenticate" mistake.
  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# -----------------------------------------------------------------------------
# Deployer service account
# -----------------------------------------------------------------------------

resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = var.deployer_account_id
  display_name = "GitHub Actions deployer"
  description  = "Impersonated by GitHub Actions via Workload Identity Federation"

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(var.deployer_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

# Read/write access to the state bucket, scoped to the bucket rather than
# granted project-wide.
resource "google_storage_bucket_iam_member" "deployer_state" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.deployer.email}"
}

# The binding that actually lets the federated identity act as the deployer.
# principalSet scopes it to tokens carrying the expected repository attribute.
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}
