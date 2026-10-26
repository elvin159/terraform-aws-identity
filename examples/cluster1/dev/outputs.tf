output "cluster_autoscaler_role_arn" {
  description = "Annotate the cluster-autoscaler service account with this ARN."
  value       = module.identity.cluster_autoscaler_role_arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "Annotate the aws-load-balancer-controller service account with this ARN."
  value       = module.identity.aws_load_balancer_controller_role_arn
}

output "external_dns_role_arn" {
  description = "Annotate the external-dns service account with this ARN."
  value       = module.identity.external_dns_role_arn
}

output "external_secrets_role_arn" {
  description = "Annotate the external-secrets service account with this ARN."
  value       = module.identity.external_secrets_role_arn
}
