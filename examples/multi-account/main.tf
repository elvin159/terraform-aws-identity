terraform {
  # Root configurations pin exact versions; commit .terraform.lock.hcl alongside this file.
  required_version = "1.17.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.70.0"
    }
  }

  # Partial configuration: terraform init -backend-config=env/<environment>.s3.tfbackend
  backend "s3" {}
}

# Authentication is OIDC only, with no static access keys. CI exchanges its GitHub OIDC token for
# a short-lived session in this environment's account (.github/workflows/terraform.yml).
# allowed_account_ids stops a run against the wrong account.
provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

module "identity" {
  # Consumers should pin a released tag, e.g.
  # source = "git::https://github.com/<org>/terraform-aws-identity.git?ref=v1.0.0"
  source = "../.."

  cluster_name      = var.cluster_name
  oidc_provider_arn = data.aws_iam_openid_connect_provider.this.arn

  cluster_autoscaler = {
    enabled = true
  }

  aws_load_balancer_controller = {
    enabled = true
  }

  external_dns = {
    enabled         = true
    hosted_zone_ids = var.hosted_zone_ids
  }

  external_secrets = {
    enabled              = true
    secrets_manager_arns = ["arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:${var.cluster_name}/*"]
  }
}
