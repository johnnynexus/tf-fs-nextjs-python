output "instance_name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "project:region:instance, used by the Cloud SQL Auth Proxy."
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip_address" {
  description = "Private IP the backend connects to."
  value       = google_sql_database_instance.this.private_ip_address
}

output "database_name" {
  description = "Application database name."
  value       = google_sql_database.app.name
}

output "database_url_secret_id" {
  description = "Short secret name holding the full connection string, for Cloud Run secret env mounting."
  value       = google_secret_manager_secret.database_url.secret_id
}

output "database_url_secret_name" {
  description = "Fully-qualified secret resource name, for IAM bindings."
  value       = google_secret_manager_secret.database_url.name
}
