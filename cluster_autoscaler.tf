# Mirrors the "Full Cluster Autoscaler Features Policy" for Cluster Autoscaler v1.36.1, with scaling
# actions restricted by tag to this cluster's Auto Scaling groups (EKS managed node groups carry the tag):
# https://github.com/kubernetes/autoscaler/blob/cluster-autoscaler-1.36.1/cluster-autoscaler/cloudprovider/aws/README.md#iam-policy

data "aws_iam_policy_document" "cluster_autoscaler" {
  count = var.cluster_autoscaler.enabled ? 1 : 0

  statement {
    sid = "AllowRead"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup",
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowScalingOwnedNodeGroups"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}"
      values   = ["owned"]
    }
  }
}

module "cluster_autoscaler" {
  source = "./modules/irsa-role"
  count  = var.cluster_autoscaler.enabled ? 1 : 0

  name                     = "${var.cluster_name}-cluster-autoscaler"
  oidc_provider_arn        = var.oidc_provider_arn
  namespace                = var.cluster_autoscaler.namespace
  service_account          = var.cluster_autoscaler.service_account
  policy_json              = data.aws_iam_policy_document.cluster_autoscaler[0].json
  permissions_boundary_arn = var.permissions_boundary_arn
  tags                     = var.tags
}
