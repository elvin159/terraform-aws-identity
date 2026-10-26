variable "name" {
  description = "Name of the IAM role."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster's IAM OIDC provider."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account allowed to assume the role."
  type        = string
}

variable "service_account" {
  description = "Name of the Kubernetes service account allowed to assume the role."
  type        = string
}

variable "policy_json" {
  description = "IAM policy document (JSON) granted to the role."
  type        = string
}

variable "permissions_boundary_arn" {
  description = "ARN of the permissions boundary to attach to the role. Null for none."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the IAM role."
  type        = map(string)
  default     = {}
}
