terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.20.0, < 7.0.0"
    }
  }

  # No remote backend: this stack *creates* the state bucket, so it cannot
  # store its own state there. terraform.tfstate stays local.
  #
  # It is small, changes rarely, and is easy to recreate by importing. If you
  # want it remote, run this once, then add a `backend "gcs"` block pointing
  # at the bucket it just created and run `terraform init -migrate-state`.
}

provider "google" {
  project = var.project_id
  region  = var.region
}
