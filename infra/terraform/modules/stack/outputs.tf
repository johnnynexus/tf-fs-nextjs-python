output "frontend_url" {
  description = "Public URL of the deployed frontend. This is the application entry point."
  value       = module.frontend.url
}

output "backend_url" {
  description = "Public URL of the deployed backend API."
  value       = module.backend.url
}

output "backend_health_url" {
  description = "Convenience URL for a post-deploy smoke test."
  value       = "${module.backend.url}/health"
}

output "backend_docs_url" {
  description = "Swagger UI for the deployed API."
  value       = "${module.backend.url}/docs"
}

output "registry_url" {
  description = "Artifact Registry base path. Tag images as <registry_url>/<frontend|backend>:<tag>."
  value       = module.registry.repository_url
}

output "registry_host" {
  description = "Registry hostname for `gcloud auth configure-docker`."
  value       = module.registry.registry_host
}

output "backend_service_name" {
  description = "Cloud Run service name for the backend."
  value       = module.backend.name
}

output "frontend_service_name" {
  description = "Cloud Run service name for the frontend."
  value       = module.frontend.name
}

output "backend_service_account" {
  description = "Backend runtime service account email."
  value       = module.backend.service_account_email
}

output "frontend_service_account" {
  description = "Frontend runtime service account email."
  value       = module.frontend.service_account_email
}

output "database_connection_name" {
  description = "Cloud SQL connection name for the Auth Proxy, or null when the database is disabled."
  value       = try(module.database[0].connection_name, null)
}

output "database_url_secret_id" {
  description = "Secret Manager secret holding the connection string, or null when the database is disabled."
  value       = try(module.database[0].database_url_secret_id, null)
}

output "using_placeholder_image" {
  description = "True when at least one service is still running the bootstrap placeholder image rather than a real build."
  value       = local.using_placeholder
}
