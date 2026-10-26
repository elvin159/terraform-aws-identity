terraform {
  # Root configurations pin exact versions; commit .terraform.lock.hcl alongside this file.
  required_version = "1.17.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.70.0"
    }
  }

  # State lives in this environment's account.
  backend "s3" {
    bucket       = "example-terraform-state-stg"
    key          = "cluster1/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

locals {
  environment  = "stg"
  account_id   = "222222222222"
  region       = "us-east-1"
  cluster_name = "cluster1-stg"
}

# Authentication is OIDC only, with no static access keys. CI exchanges its GitHub OIDC token for
# a short-lived session in this environment's account (.github/workflows/terraform.yml).
# allowed_account_ids stops a run against the wrong account.
provider "aws" {
  region              = local.region
  allowed_account_ids = [local.account_id]

  default_tags {
    tags = {
      Cluster     = "cluster1"
      Environment = local.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

module "identity" {
  # Consumers should pin a released tag, e.g.
  # source = "git::https://github.com/<org>/terraform-aws-identity.git?ref=v1.0.0"
  source = "../../.."

  cluster_name      = local.cluster_name
  oidc_provider_arn = data.aws_iam_openid_connect_provider.this.arn

  cluster_autoscaler = {
    enabled = true
  }

  aws_load_balancer_controller = {
    enabled = true
  }

  external_dns = {
    enabled         = true
    hosted_zone_ids = ["Z0000000000000000000"]
  }

  external_secrets = {
    enabled              = true
    secrets_manager_arns = ["arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${local.cluster_name}/*"]
  }
}
