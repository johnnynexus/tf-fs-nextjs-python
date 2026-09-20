variable "project_id" {
  description = "GCP project that owns the Artifact Registry repository."
  type        = string
}

variable "region" {
  description = "Region for the repository. Keep it the same as the Cloud Run region so image pulls stay in-region (faster cold starts, no egress cost)."
  type        = string
}

variable "repository_id" {
  description = "Repository name, e.g. \"myapp-dev\". Images are pushed to <region>-docker.pkg.dev/<project>/<repository_id>/<image>."
  type        = string
}

variable "labels" {
  description = "Labels applied to the repository."
  type        = map(string)
  default     = {}
}

variable "keep_recent_versions" {
  description = "Number of recent image versions to retain per image. Older untagged versions are deleted to keep storage costs near zero."
  type        = number
  default     = 10
}

variable "delete_untagged_after" {
  description = "Age after which untagged images are deleted, as a Go duration string (e.g. \"604800s\" for 7 days)."
  type        = string
  default     = "604800s"
}
