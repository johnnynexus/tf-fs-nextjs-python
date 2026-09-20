# -----------------------------------------------------------------------------
# Remote state.
#
# GCS is used rather than S3+DynamoDB because this stack is on GCP. GCS object
# versioning plus native state locking covers what the DynamoDB table provides
# on AWS - Terraform takes a lock on the state object itself, so no separate
# lock table is needed.
#
# The configuration is intentionally *partial*: the bucket differs per
# environment and is supplied at init time, so this file never has to be
# edited or templated.
#
#   terraform init -backend-config=backend.hcl
#
# The bucket itself is created by infra/terraform/bootstrap, which keeps its
# own state locally (it cannot store state in a bucket it has not created
# yet).
# -----------------------------------------------------------------------------

terraform {
  backend "gcs" {}
}
