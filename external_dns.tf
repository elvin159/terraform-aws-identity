# https://kubernetes-sigs.github.io/external-dns/latest/docs/tutorials/aws/

data "aws_iam_policy_document" "external_dns" {
  count = var.external_dns.enabled ? 1 : 0

  statement {
    sid       = "AllowChangeRecordsInManagedZones"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [for id in var.external_dns.hosted_zone_ids : "arn:${local.partition}:route53:::hostedzone/${id}"]
  }

  statement {
    sid = "AllowRead"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
      "route53:ListTagsForResources",
    ]
    resources = ["*"]
  }
}

module "external_dns" {
  source = "./modules/irsa-role"
  count  = var.external_dns.enabled ? 1 : 0

  name                     = "${var.cluster_name}-external-dns"
  oidc_provider_arn        = var.oidc_provider_arn
  namespace                = var.external_dns.namespace
  service_account          = var.external_dns.service_account
  policy_json              = data.aws_iam_policy_document.external_dns[0].json
  permissions_boundary_arn = var.permissions_boundary_arn
  tags                     = var.tags
}
