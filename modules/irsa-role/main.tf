locals {
  # arn:aws:iam::111122223333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE
  #   -> oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE
  oidc_issuer = element(split("oidc-provider/", var.oidc_provider_arn), 1)
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "AllowServiceAccountAssumeRole"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name                  = var.name
  assume_role_policy    = data.aws_iam_policy_document.assume_role.json
  permissions_boundary  = var.permissions_boundary_arn
  force_detach_policies = true
  tags                  = var.tags
}

resource "aws_iam_role_policy" "this" {
  name   = var.name
  role   = aws_iam_role.this.id
  policy = var.policy_json
}
