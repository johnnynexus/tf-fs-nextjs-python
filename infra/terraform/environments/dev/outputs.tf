# Surfaced by `terraform output` and consumed by the deploy workflow's smoke
# test and job summary.

output "frontend_url" {
  description = "Public URL of the frontend - the application entry point."
  value       = module.stack.frontend_url
}

output "backend_url" {
  description = "Public URL of the backend API."
  value       = module.stack.backend_url
}

output "backend_health_url" {
  description = "Backend health endpoint, used for the post-deploy smoke test."
  value       = module.stack.backend_health_url
}

output "backend_docs_url" {
  description = "Swagger UI for the deployed API."
  value       = module.stack.backend_docs_url
}

output "registry_url" {
  description = "Artifact Registry base path for image pushes."
  value       = module.stack.registry_url
}

output "backend_service_name" {
  description = "Cloud Run service name for the backend."
  value       = module.stack.backend_service_name
}

output "frontend_service_name" {
  description = "Cloud Run service name for the frontend."
  value       = module.stack.frontend_service_name
}

output "database_connection_name" {
  description = "Cloud SQL connection name, or null when the database is disabled."
  value       = module.stack.database_connection_name
}

output "using_placeholder_image" {
  description = "True while a service still runs the bootstrap placeholder rather than a real build."
  value       = module.stack.using_placeholder_image
}
