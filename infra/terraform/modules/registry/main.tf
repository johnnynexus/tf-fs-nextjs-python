# -----------------------------------------------------------------------------
# Artifact Registry: the Docker repository CI pushes frontend and backend
# images to, and that Cloud Run pulls from.
#
# Artifact Registry is used rather than the legacy Container Registry (gcr.io),
# which is shut down. Cleanup policies are configured so a busy CI pipeline
# does not accumulate unbounded storage cost.
# -----------------------------------------------------------------------------

resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = "Container images for ${var.repository_id}"
  format        = "DOCKER"
  labels        = var.labels

  # Set to true to preview what the policies below would delete without
  # actually deleting anything.
  cleanup_policy_dry_run = false

  # KEEP policies are evaluated before DELETE policies, so the most recent
  # versions survive regardless of the delete rule.
  cleanup_policies {
    id     = "keep-recent-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = var.keep_recent_versions
    }
  }

  cleanup_policies {
    id     = "delete-old-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = var.delete_untagged_after
    }
  }
}
