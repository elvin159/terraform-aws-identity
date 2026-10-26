output "cluster_autoscaler_role_arn" {
  description = "ARN of the Cluster Autoscaler role, or null if disabled."
  value       = one(module.cluster_autoscaler[*].arn)
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller role, or null if disabled."
  value       = one(module.aws_load_balancer_controller[*].arn)
}

output "external_dns_role_arn" {
  description = "ARN of the ExternalDNS role, or null if disabled."
  value       = one(module.external_dns[*].arn)
}

output "external_secrets_role_arn" {
  description = "ARN of the External Secrets Operator role, or null if disabled."
  value       = one(module.external_secrets[*].arn)
}
