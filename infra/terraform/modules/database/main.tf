# -----------------------------------------------------------------------------
# Cloud SQL for PostgreSQL.
#
# This whole module is optional: environments set `enable_database = false` by
# default because Cloud SQL has no free tier (~$8/month at the smallest tier,
# billed whether or not anything queries it). The backend is written to run
# fine without it.
#
# The instance uses a *private IP only*. There is no public endpoint to
# firewall, and the backend reaches it over direct VPC egress. Connect from a
# laptop with the Cloud SQL Auth Proxy rather than by enabling public IP.
#
# The generated password is stored in Secret Manager and injected into Cloud
# Run by reference, so the plaintext never appears in the service definition.
# It *does* appear in Terraform state - which is why the state bucket created
# by infra/terraform/bootstrap has uniform access control and versioning.
# -----------------------------------------------------------------------------

resource "random_password" "db" {
  length = 32
  # Cloud SQL rejects some punctuation in passwords, and this set avoids
  # anything that needs escaping in a URL.
  special          = true
  override_special = "!#$%*()-_=+[]{}<>:?"
}

# A random suffix avoids the "instance name cannot be reused for one week
# after deletion" restriction, which otherwise blocks a destroy/apply cycle.
resource "random_id" "instance_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "this" {
  project          = var.project_id
  name             = "${var.name_prefix}-pg-${random_id.instance_suffix.hex}"
  region           = var.region
  database_version = var.database_version

  # Terraform-level guard, separate from the API-level setting below.
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size_gb
    disk_type         = "PD_SSD"
    disk_autoresize   = true
    user_labels       = var.labels

    # API-level guard. Kept in step with the Terraform-level one so a single
    # variable governs both.
    deletion_protection_enabled = var.deletion_protection

    ip_configuration {
      # No public IP. The only path in is the VPC peering.
      ipv4_enabled    = false
      private_network = var.network_id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = var.backup_enabled
      start_time                     = "03:00"
      point_in_time_recovery_enabled = var.point_in_time_recovery
      transaction_log_retention_days = var.point_in_time_recovery ? 7 : null

      dynamic "backup_retention_settings" {
        for_each = var.backup_enabled ? [1] : []

        content {
          retained_backups = var.backup_retention_days
          retention_unit   = "COUNT"
        }
      }
    }

    maintenance_window {
      day          = 7 # Sunday
      hour         = 4
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled = true
      query_string_length    = 1024
    }
  }

  lifecycle {
    # The suffix is random; recreating the instance because of it would
    # destroy the database.
    ignore_changes = [name]
  }
}

resource "google_sql_database" "app" {
  project  = var.project_id
  name     = var.database_name
  instance = google_sql_database_instance.this.name

  # Avoids "database is being accessed by other users" on destroy.
  deletion_policy = "ABANDON"
}

resource "google_sql_user" "app" {
  project  = var.project_id
  name     = var.database_user
  instance = google_sql_database_instance.this.name
  password = random_password.db.result

  deletion_policy = "ABANDON"
}

# --- Connection string in Secret Manager -------------------------------------

resource "google_secret_manager_secret" "database_url" {
  project   = var.project_id
  secret_id = "${var.name_prefix}-database-url"
  labels    = var.labels

  replication {
    # Automatic replication is simplest; switch to user_managed if you have a
    # data residency requirement.
    auto {}
  }
}

resource "google_secret_manager_secret_version" "database_url" {
  secret = google_secret_manager_secret.database_url.id

  # SQLAlchemy normalises the postgresql:// scheme to asyncpg at runtime, so
  # this value also works with psql and the Cloud SQL Auth Proxy.
  #
  # The password is url-encoded because the generated character set includes
  # characters that are not valid unescaped in a URI userinfo component.
  #
  # Note: this lands in Terraform state. The write-only `secret_data_wo`
  # argument avoids that, but requires Terraform >= 1.11; bump
  # required_version and switch if your toolchain allows it. Either way the
  # state bucket must be treated as sensitive - see infra/terraform/bootstrap.
  secret_data = format(
    "postgresql://%s:%s@%s:5432/%s",
    var.database_user,
    urlencode(random_password.db.result),
    google_sql_database_instance.this.private_ip_address,
    var.database_name,
  )
}
