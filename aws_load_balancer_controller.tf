# Mirrors the AWS Load Balancer Controller v3.6.2 reference policy:
# https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v3.6.2/docs/install/iam_policy.json

locals {
  alb_elb_arn_prefix = "arn:${local.partition}:elasticloadbalancing:*:*"
  alb_sg_arn         = "arn:${local.partition}:ec2:*:*:security-group/*"

  alb_taggable_lb_arns = [
    "${local.alb_elb_arn_prefix}:targetgroup/*/*",
    "${local.alb_elb_arn_prefix}:loadbalancer/net/*/*",
    "${local.alb_elb_arn_prefix}:loadbalancer/app/*/*",
  ]
}

data "aws_iam_policy_document" "aws_load_balancer_controller" {
  count = var.aws_load_balancer_controller.enabled ? 1 : 0

  statement {
    sid       = "AllowCreateServiceLinkedRole"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }

  statement {
    sid = "AllowDescribe"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "ec2:GetSecurityGroupsForVpc",
      "ec2:DescribeIpamPools",
      "ec2:DescribeRouteTables",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTrustStores",
      "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:DescribeCapacityReservation",
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowIntegrations"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection",
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowSecurityGroupIngress"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "AllowCreateSecurityGroup"
    actions   = ["ec2:CreateSecurityGroup"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowTagSecurityGroupOnCreate"
    actions   = ["ec2:CreateTags"]
    resources = [local.alb_sg_arn]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid = "AllowTagManagedSecurityGroups"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = [local.alb_sg_arn]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid = "AllowManageManagedSecurityGroups"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup",
    ]
    resources = ["*"]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid = "AllowCreateLoadBalancers"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
    ]
    resources = ["*"]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid = "AllowManageListenersAndRules"
    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowTagManagedLoadBalancers"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]
    resources = local.alb_taggable_lb_arns

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid = "AllowTagListenersAndRules"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]
    resources = [
      "${local.alb_elb_arn_prefix}:listener/net/*/*/*",
      "${local.alb_elb_arn_prefix}:listener/app/*/*/*",
      "${local.alb_elb_arn_prefix}:listener-rule/net/*/*/*",
      "${local.alb_elb_arn_prefix}:listener-rule/app/*/*/*",
    ]
  }

  statement {
    sid = "AllowModifyManagedLoadBalancers"
    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyListenerAttributes",
      "elasticloadbalancing:ModifyCapacityReservation",
      "elasticloadbalancing:ModifyIpPools",
    ]
    resources = ["*"]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid       = "AllowTagLoadBalancersOnCreate"
    actions   = ["elasticloadbalancing:AddTags"]
    resources = local.alb_taggable_lb_arns

    condition {
      test     = "StringEquals"
      variable = "elasticloadbalancing:CreateAction"
      values   = ["CreateTargetGroup", "CreateLoadBalancer"]
    }

    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid = "AllowRegisterTargets"
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
    ]
    resources = ["${local.alb_elb_arn_prefix}:targetgroup/*/*"]
  }

  statement {
    sid = "AllowModifyListeners"
    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:SetRulePriorities",
    ]
    resources = ["*"]
  }
}

module "aws_load_balancer_controller" {
  source = "./modules/irsa-role"
  count  = var.aws_load_balancer_controller.enabled ? 1 : 0

  name                     = "${var.cluster_name}-aws-load-balancer-controller"
  oidc_provider_arn        = var.oidc_provider_arn
  namespace                = var.aws_load_balancer_controller.namespace
  service_account          = var.aws_load_balancer_controller.service_account
  policy_json              = data.aws_iam_policy_document.aws_load_balancer_controller[0].json
  permissions_boundary_arn = var.permissions_boundary_arn
  tags                     = var.tags
}
