output "url" {
  description = "Public HTTPS URL of the frontend - this is the app's entry point."
  value       = module.service.url
}

output "name" {
  description = "Cloud Run service name."
  value       = module.service.name
}

output "service_account_email" {
  description = "Frontend runtime service account."
  value       = module.service.service_account_email
}
