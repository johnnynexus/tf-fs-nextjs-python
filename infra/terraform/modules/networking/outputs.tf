output "network_id" {
  description = "Full resource ID of the VPC."
  value       = google_compute_network.vpc.id
}

output "network_name" {
  description = "VPC name."
  value       = google_compute_network.vpc.name
}

output "subnet_id" {
  description = "Full resource ID of the application subnet, used by Cloud Run direct VPC egress."
  value       = google_compute_subnetwork.app.id
}

output "subnet_name" {
  description = "Application subnet name."
  value       = google_compute_subnetwork.app.name
}

output "private_service_connection_id" {
  description = "ID of the service networking peering, or null when disabled. Cloud SQL must depend on this so the peering exists before the instance is created."
  value       = try(google_service_networking_connection.private_service_connection[0].id, null)
}
