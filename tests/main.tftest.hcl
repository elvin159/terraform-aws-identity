# Offline tests: plan only, with dummy credentials (never real keys) and overridden AWS lookups.
# Run with: terraform init && terraform test

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

override_data {
  target = data.aws_partition.current
  values = { partition = "aws" }
}

variables {
  cluster_name      = "dev"
  oidc_provider_arn = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
}

run "nothing_enabled_by_default" {
  command = plan

  assert {
    condition     = length(module.cluster_autoscaler) + length(module.aws_load_balancer_controller) + length(module.external_dns) + length(module.external_secrets) == 0
    error_message = "No roles should be created unless enabled."
  }
}

run "all_roles" {
  command = plan

  variables {
    cluster_autoscaler           = { enabled = true }
    aws_load_balancer_controller = { enabled = true }
    external_dns = {
      enabled         = true
      hosted_zone_ids = ["Z0000000000000000000"]
    }
    external_secrets = {
      enabled              = true
      secrets_manager_arns = ["arn:aws:secretsmanager:us-east-1:111111111111:secret:dev/*"]
    }
  }

  assert {
    condition     = module.cluster_autoscaler[0].name == "dev-cluster-autoscaler"
    error_message = "Unexpected Cluster Autoscaler role name."
  }

  assert {
    condition = jsondecode(module.cluster_autoscaler[0].assume_role_policy).Statement[0].Condition.StringEquals == {
      "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
      "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE:aud" = "sts.amazonaws.com"
    }
    error_message = "Trust policy must be scoped to the Cluster Autoscaler service account."
  }

  assert {
    condition = jsondecode(data.aws_iam_policy_document.cluster_autoscaler[0].json).Statement[1].Condition.StringEquals == {
      "aws:ResourceTag/k8s.io/cluster-autoscaler/dev" = "owned"
    }
    error_message = "Cluster Autoscaler scaling actions must be scoped to this cluster's Auto Scaling groups."
  }

  assert {
    condition     = jsondecode(data.aws_iam_policy_document.external_dns[0].json).Statement[0].Resource == "arn:aws:route53:::hostedzone/Z0000000000000000000"
    error_message = "ExternalDNS must be scoped to the given hosted zone."
  }
}

run "external_dns_requires_zones" {
  command = plan

  variables {
    external_dns = { enabled = true }
  }

  expect_failures = [var.external_dns]
}

run "external_secrets_requires_scope" {
  command = plan

  variables {
    external_secrets = { enabled = true }
  }

  expect_failures = [var.external_secrets]
}
