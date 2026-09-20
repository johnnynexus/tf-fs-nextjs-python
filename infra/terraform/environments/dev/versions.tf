terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.20.0, < 7.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  # No credentials block on purpose. Authentication comes from Application
  # Default Credentials: `gcloud auth application-default login` locally, and
  # Workload Identity Federation (OIDC) in GitHub Actions. There is no
  # service account key file anywhere in this repository.
}
