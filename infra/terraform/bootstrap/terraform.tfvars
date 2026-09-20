# Bootstrap values for the nexus-gcloud-sandbox project.
# Contains no secrets: project and bucket names are not sensitive, and
# authentication happens via ADC locally / OIDC in CI.

project_id = "nexus-gcloud-sandbox"
region     = "us-west1"

# Globally unique across all of GCS.
state_bucket_name = "nexus-tfs-tfstate"

# The security boundary: only workflows in this repository can federate in.
github_repository = "johnnynexus/tf-fs-nextjs-python"

pool_id     = "github-pool"
provider_id = "github-provider"
