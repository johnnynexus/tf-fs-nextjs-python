# Partial backend configuration for the dev remote state.
#   terraform init -backend-config=backend.hcl
#
# The bucket is created by infra/terraform/bootstrap. Replace the name below
# with the `state_bucket_name` it outputs (bucket names are globally unique,
# so this cannot be a fixed default).
bucket = "nexus-tfs-tfstate"
prefix = "env/dev"
