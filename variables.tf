variable "cluster_name" {
  description = "Name of the EKS cluster. Used to scope the Cluster Autoscaler policy and to prefix role names."
  type        = string

  validation {
    # Longest role name suffix is "-aws-load-balancer-controller" (29 chars); IAM allows 64.
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 35
    error_message = "cluster_name must be between 1 and 35 characters so derived IAM role names fit within 64 characters."
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster's IAM OIDC provider."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:oidc-provider/.+$", var.oidc_provider_arn))
    error_message = "oidc_provider_arn must be an IAM OIDC provider ARN."
  }
}

variable "permissions_boundary_arn" {
  description = "ARN of a permissions boundary to attach to every role. Null for none."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every IAM role."
  type        = map(string)
  default     = {}
}

variable "cluster_autoscaler" {
  description = "Cluster Autoscaler role. Can only scale Auto Scaling groups tagged k8s.io/cluster-autoscaler/<cluster_name>=owned."
  type = object({
    enabled         = optional(bool, false)
    namespace       = optional(string, "kube-system")
    service_account = optional(string, "cluster-autoscaler")
  })
  default = {}
}

variable "aws_load_balancer_controller" {
  description = "AWS Load Balancer Controller role."
  type = object({
    enabled         = optional(bool, false)
    namespace       = optional(string, "kube-system")
    service_account = optional(string, "aws-load-balancer-controller")
  })
  default = {}
}

variable "external_dns" {
  description = "ExternalDNS role. hosted_zone_ids lists the Route 53 zones ExternalDNS may modify."
  type = object({
    enabled         = optional(bool, false)
    namespace       = optional(string, "kube-system")
    service_account = optional(string, "external-dns")
    hosted_zone_ids = optional(list(string), [])
  })
  default = {}

  validation {
    condition     = !var.external_dns.enabled || length(var.external_dns.hosted_zone_ids) > 0
    error_message = "external_dns.hosted_zone_ids must contain at least one zone ID when external_dns.enabled is true."
  }
}

variable "external_secrets" {
  description = "External Secrets Operator role. Grants read-only access to the listed Secrets Manager secrets and SSM parameters, and decrypt on the listed KMS keys."
  type = object({
    enabled              = optional(bool, false)
    namespace            = optional(string, "external-secrets")
    service_account      = optional(string, "external-secrets")
    secrets_manager_arns = optional(list(string), [])
    ssm_parameter_arns   = optional(list(string), [])
    kms_key_arns         = optional(list(string), [])
  })
  default = {}

  validation {
    condition = !var.external_secrets.enabled || (
      length(var.external_secrets.secrets_manager_arns) + length(var.external_secrets.ssm_parameter_arns) > 0
    )
    error_message = "external_secrets requires at least one entry in secrets_manager_arns or ssm_parameter_arns when enabled."
  }
}
