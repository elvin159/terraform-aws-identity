variable "environment" {
  description = "Environment name."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev, staging, prod."
  }
}

variable "account_id" {
  description = "AWS account ID for this environment. The provider refuses to run against any other account."
  type        = string
}

variable "region" {
  description = "AWS region of the EKS cluster."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "hosted_zone_ids" {
  description = "Route 53 hosted zone IDs ExternalDNS may manage."
  type        = list(string)
}
