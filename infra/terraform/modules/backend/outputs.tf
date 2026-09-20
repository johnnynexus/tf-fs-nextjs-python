output "url" {
  description = "Public HTTPS URL of the backend service."
  value       = module.service.url
}

output "name" {
  description = "Cloud Run service name."
  value       = module.service.name
}

output "service_account_email" {
  description = "Backend runtime service account."
  value       = module.service.service_account_email
}
