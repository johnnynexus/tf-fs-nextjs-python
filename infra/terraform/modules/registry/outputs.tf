output "repository_id" {
  description = "Short repository name."
  value       = google_artifact_registry_repository.this.repository_id
}

output "repository_name" {
  description = "Fully-qualified repository resource name."
  value       = google_artifact_registry_repository.this.name
}

output "registry_host" {
  description = "Docker registry hostname to authenticate against (docker login / gcloud auth configure-docker)."
  value       = "${var.region}-docker.pkg.dev"
}

output "repository_url" {
  description = "Base path for image references. Append /<image>:<tag>."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
}
