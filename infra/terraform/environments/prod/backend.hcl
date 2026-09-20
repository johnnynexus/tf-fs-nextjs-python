# Partial backend configuration for the prod remote state.
#   terraform init -backend-config=backend.hcl
#
# Same bucket as dev, different prefix: one bucket keeps the bootstrap simple,
# and the prefix isolates the two state files. Use separate buckets in
# separate projects if you need a hard IAM boundary between environments.
bucket = "REPLACE_ME-tfstate"
prefix = "env/prod"
