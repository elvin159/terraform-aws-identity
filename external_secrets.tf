# https://external-secrets.io/latest/provider/aws-secrets-manager/
# https://external-secrets.io/latest/provider/aws-parameter-store/

data "aws_iam_policy_document" "external_secrets" {
  count = var.external_secrets.enabled ? 1 : 0

  dynamic "statement" {
    for_each = length(var.external_secrets.secrets_manager_arns) > 0 ? [1] : []

    content {
      sid = "AllowReadSecretsManager"
      actions = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:ListSecretVersionIds",
      ]
      resources = var.external_secrets.secrets_manager_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.external_secrets.ssm_parameter_arns) > 0 ? [1] : []

    content {
      sid = "AllowReadParameterStore"
      actions = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
      ]
      resources = var.external_secrets.ssm_parameter_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.external_secrets.kms_key_arns) > 0 ? [1] : []

    content {
      sid       = "AllowDecrypt"
      actions   = ["kms:Decrypt"]
      resources = var.external_secrets.kms_key_arns
    }
  }
}

module "external_secrets" {
  source = "./modules/irsa-role"
  count  = var.external_secrets.enabled ? 1 : 0

  name                     = "${var.cluster_name}-external-secrets"
  oidc_provider_arn        = var.oidc_provider_arn
  namespace                = var.external_secrets.namespace
  service_account          = var.external_secrets.service_account
  policy_json              = data.aws_iam_policy_document.external_secrets[0].json
  permissions_boundary_arn = var.permissions_boundary_arn
  tags                     = var.tags
}
