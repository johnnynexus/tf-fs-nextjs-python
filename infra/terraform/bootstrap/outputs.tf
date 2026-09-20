output "state_bucket_name" {
  description = "Put this in each environment's backend.hcl as `bucket`."
  value       = google_storage_bucket.state.name
}

output "workload_identity_provider" {
  description = "Value for the GitHub secret/variable GCP_WORKLOAD_IDENTITY_PROVIDER, passed to google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deployer_service_account_email" {
  description = "Value for the GitHub secret/variable GCP_SERVICE_ACCOUNT."
  value       = google_service_account.deployer.email
}

output "github_configuration_summary" {
  description = "Copy-paste summary of what to configure in GitHub."
  value       = <<-EOT
    Configure these in GitHub (Settings -> Secrets and variables -> Actions):

      Repository variables (not secrets - none of this is sensitive):
        GCP_PROJECT_ID                  = ${var.project_id}
        GCP_REGION                      = ${var.region}
        GCP_WORKLOAD_IDENTITY_PROVIDER  = ${google_iam_workload_identity_pool_provider.github.name}
        GCP_SERVICE_ACCOUNT             = ${google_service_account.deployer.email}
        TF_STATE_BUCKET                 = ${google_storage_bucket.state.name}

    Then set the same variables per GitHub Environment (dev, prod) if the
    environments live in different GCP projects.

    Nothing above is a credential: authentication happens through OIDC, and
    the trust is scoped to the repository "${var.github_repository}".
  EOT
}
