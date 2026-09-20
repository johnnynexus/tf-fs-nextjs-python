output "url" {
  description = "HTTPS URL of the service, assigned by Cloud Run."
  value       = google_cloud_run_v2_service.this.uri
}

output "name" {
  description = "Cloud Run service name."
  value       = google_cloud_run_v2_service.this.name
}

output "id" {
  description = "Full resource ID of the service."
  value       = google_cloud_run_v2_service.this.id
}

output "service_account_email" {
  description = "Email of the runtime service account, for granting further IAM."
  value       = google_service_account.runtime.email
}

output "latest_revision" {
  description = "Name of the most recently created revision."
  value       = google_cloud_run_v2_service.this.latest_created_revision
}
