terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source = "hashicorp/google"
      # Pinned below the next major so a provider release cannot silently
      # change resource behaviour. >= 6.20 guarantees the Cloud Run v2
      # `deletion_protection` argument used by the service modules.
      version = ">= 6.20.0, < 7.0.0"
    }
  }
}
