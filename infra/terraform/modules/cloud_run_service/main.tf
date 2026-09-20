# -----------------------------------------------------------------------------
# Generic Cloud Run v2 service.
#
# Both the frontend and the backend are containers with the same deployment
# shape, so the shared mechanics live here and the app-specific modules
# (modules/frontend, modules/backend) supply only what differs: image, env
# vars, sizing and whether VPC access is needed.
#
# Why Cloud Run rather than GKE or Compute Engine: it scales to zero (an idle
# environment costs nothing), needs no cluster to operate, and handles TLS,
# autoscaling and revision-based rollout out of the box. For a two-service
# stack, anything heavier is unjustified operational surface.
# -----------------------------------------------------------------------------

locals {
  # Referencing this in the service forces Terraform to order the service
  # after whatever the caller passed in (e.g. secret IAM bindings).
  dependency_fingerprint = join(",", var.depends_on_resources)
}

# --- Runtime identity --------------------------------------------------------
# Each service gets a dedicated service account. The default Compute Engine
# service account is deliberately avoided: it is shared and over-privileged.

resource "google_service_account" "runtime" {
  project    = var.project_id
  account_id = "${substr(var.service_name, 0, 28)}-sa"
  # account_id is capped at 30 characters, hence the substr above.
  display_name = "Runtime identity for ${var.service_name}"
  description  = "Least-privilege identity used by the ${var.service_name} Cloud Run service"
}

resource "google_project_iam_member" "runtime_roles" {
  for_each = toset(var.service_account_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# --- The service -------------------------------------------------------------

resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = var.service_name
  location = var.region
  ingress  = var.ingress
  labels   = var.labels

  deletion_protection = var.deletion_protection

  template {
    service_account                  = google_service_account.runtime.email
    timeout                          = "${var.request_timeout_seconds}s"
    max_instance_request_concurrency = var.max_concurrency

    # Labels are also applied to revisions so cost reports can attribute
    # spend per environment.
    labels = merge(var.labels, {
      # Changes whenever an upstream dependency changes, which is enough to
      # keep the implicit ordering visible in the plan.
      "dependency-hash" = substr(sha256(local.dependency_fingerprint), 0, 12)
    })

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    # Direct VPC egress. Omitted entirely when var.vpc_access is null, so the
    # default deployment has no VPC attachment and no associated cost.
    dynamic "vpc_access" {
      for_each = var.vpc_access == null ? [] : [var.vpc_access]

      content {
        egress = vpc_access.value.egress

        network_interfaces {
          network    = vpc_access.value.network_id
          subnetwork = vpc_access.value.subnet_id
        }
      }
    }

    containers {
      image = var.image

      ports {
        # Cloud Run passes this through as the PORT env var.
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle          = var.cpu_idle
        startup_cpu_boost = var.startup_cpu_boost
      }

      dynamic "env" {
        for_each = var.env

        content {
          name  = env.key
          value = env.value
        }
      }

      # Secrets are mounted by reference, so the value never appears in the
      # service definition or in Terraform state.
      dynamic "env" {
        for_each = var.secret_env

        content {
          name = env.key

          value_source {
            secret_key_ref {
              secret  = env.value.secret_id
              version = env.value.version
            }
          }
        }
      }

      # Gates traffic until the app reports healthy. Without this, Cloud Run
      # sends requests as soon as the port is open.
      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds       = 3
        period_seconds        = 3
        failure_threshold     = var.startup_probe_failure_threshold

        http_get {
          path = var.startup_probe_path
          port = var.container_port
        }
      }

      dynamic "liveness_probe" {
        for_each = var.liveness_probe_path == null ? [] : [var.liveness_probe_path]

        content {
          timeout_seconds   = 3
          period_seconds    = 30
          failure_threshold = 3

          http_get {
            path = liveness_probe.value
            port = var.container_port
          }
        }
      }
    }
  }

  traffic {
    # Always send 100% to the newest revision. Swap in a revision-pinned
    # split here if you want canary releases.
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [google_project_iam_member.runtime_roles]
}

# --- Public access -----------------------------------------------------------
# Cloud Run services are private by default; this is what makes them reachable
# from a browser. Gated by a variable so an internal-only service can opt out.

resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count = var.allow_public_access ? 1 : 0

  project  = var.project_id
  location = google_cloud_run_v2_service.this.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
