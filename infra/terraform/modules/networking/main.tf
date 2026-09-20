# -----------------------------------------------------------------------------
# Networking.
#
# Design note: Cloud Run v2 supports *Direct VPC egress*, which attaches
# instances straight to a subnet. The older Serverless VPC Access Connector
# would work too, but it runs a managed instance group that costs roughly
# $9/month even when idle. Direct egress has no standing cost, which matters
# for a reference stack that should be nearly free when unused.
#
# The VPC and subnet are always created (both are free) so the network layout
# does not change shape when the database is toggled on. Only the private
# services peering - which is only needed for Cloud SQL private IP - is
# conditional.
# -----------------------------------------------------------------------------

resource "google_compute_network" "vpc" {
  project = var.project_id
  name    = "${var.name_prefix}-vpc"

  # Manual subnets only: auto mode creates a subnet in every region, which is
  # noise we do not want.
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "VPC for ${var.name_prefix}"
}

resource "google_compute_subnetwork" "app" {
  project       = var.project_id
  name          = "${var.name_prefix}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.subnet_cidr

  # Lets instances reach Google APIs (Secret Manager, Cloud SQL admin) over
  # internal IPs instead of routing through the public internet.
  private_ip_google_access = true
}

# --- Private Services Access (Cloud SQL private IP) --------------------------
# Cloud SQL instances with a private IP live in a Google-managed VPC that is
# peered with ours. That peering needs a CIDR range reserved up front.

resource "google_compute_global_address" "private_service_range" {
  count = var.enable_private_service_access ? 1 : 0

  project       = var.project_id
  name          = "${var.name_prefix}-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.private_service_access_prefix_length
  network       = google_compute_network.vpc.id
  description   = "Reserved range for Google-managed services (Cloud SQL)"
}

resource "google_service_networking_connection" "private_service_connection" {
  count = var.enable_private_service_access ? 1 : 0

  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range[0].name]

  # Without this, `terraform destroy` leaves the peering behind and the VPC
  # cannot be deleted.
  deletion_policy = "ABANDON"
}
