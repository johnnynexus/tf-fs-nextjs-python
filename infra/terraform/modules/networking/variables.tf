variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for the subnet."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for all network resource names, e.g. \"myapp-dev\"."
  type        = string
}

variable "subnet_cidr" {
  description = "Primary CIDR for the application subnet. Cloud Run direct VPC egress allocates one IP per instance from this range, so size it for peak concurrency."
  type        = string
  default     = "10.10.0.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "enable_private_service_access" {
  description = "Create the VPC peering that Cloud SQL private IP requires. Only needed when the database is enabled; it costs nothing but adds ~5 minutes to the first apply."
  type        = bool
  default     = false
}

variable "private_service_access_prefix_length" {
  description = "Prefix length for the range reserved for Google-managed services (Cloud SQL). /16 is Google's recommendation and leaves room for more managed services later."
  type        = number
  default     = 16
}
