# terraform-aws-identity

Creates IRSA roles (IAM Roles for Service Accounts) for these EKS add-ons:

| Add-on | Setting | Role created |
|---|---|---|
| Cluster Autoscaler | `cluster_autoscaler` | `<cluster_name>-cluster-autoscaler` |
| AWS Load Balancer Controller | `aws_load_balancer_controller` | `<cluster_name>-aws-load-balancer-controller` |
| ExternalDNS | `external_dns` | `<cluster_name>-external-dns` |
| External Secrets Operator | `external_secrets` | `<cluster_name>-external-secrets` |

Each role can only be assumed by one Kubernetes service account through the cluster's OIDC provider.
No static AWS keys are used anywhere.

## How it works

- **One AWS account per environment** (dev, stg, prd). The module itself has no environment
  logic. Each environment calls it from its own root configuration.
- **One folder per environment.** [`examples/cluster1`](examples/cluster1) shows the layout of a
  cluster repo. Each environment folder is a separate Terraform root with its own state:

  ```
  cluster1/              # repo root for one Kubernetes cluster
  ├── dev/               # Terraform root: dev account
  │   ├── main.tf        #   backend, provider, environment values, module calls
  │   ├── outputs.tf
  │   └── .terraform.lock.hcl
  ├── stg/               # Terraform root: stg account
  └── prd/               # Terraform root: prd account
  ```

  The environment's values (account ID, region, cluster name, state bucket) are written directly
  in its `main.tf`. To work on an environment, `cd` into its folder; there are no tfvars or
  backend files to pick.
- **Wrong-account protection:** the provider sets `allowed_account_ids`, so Terraform refuses to
  run if your credentials belong to a different account than the folder is for.
- **Changes ship through CI:** open a PR to see the plan for every environment. Merge to apply
  dev, then stg, then prd. See [CI/CD](#cicd).

## Making a change

1. Edit `examples/cluster1/<env>/main.tf` for each environment you want to change. To roll a
   change out gradually, change `dev` first and the other environments in later PRs.
2. Open a PR. Review the `plan` job summary for each environment.
3. Get approval and merge. `apply` runs dev, then stg, then prd.
4. Put the role ARNs from the outputs into the Helm charts (see [Connecting to Helm](#connecting-to-helm)).

### Running a plan locally

Use SSO or another short-lived credential, never access keys:

```sh
cd examples/cluster1/dev
aws sso login --profile dev
export AWS_PROFILE=dev

terraform init
terraform plan -lock=false
```

Leave applies to CI.

## Settings

### Required

| Setting | Description |
|---|---|
| `cluster_name` | EKS cluster name. Prefixes role names and scopes the Cluster Autoscaler policy. Max 35 characters. |
| `oidc_provider_arn` | The cluster's IAM OIDC provider ARN. The example looks it up from `cluster_name`. |

### Optional

| Setting | Default | Description |
|---|---|---|
| `permissions_boundary_arn` | `null` | Permissions boundary attached to every role. Set it if your accounts require one. |
| `tags` | `{}` | Tags on every role. |

### Add-ons

Every add-on is off unless you set `enabled = true`. Each one also accepts `namespace` and
`service_account`; change these only if you install the chart somewhere non-standard.

| Setting | Default namespace / service account | Extra fields | What the role can do |
|---|---|---|---|
| `cluster_autoscaler` | `kube-system` / `cluster-autoscaler` | none | Describe ASGs and EC2. Scale or terminate only ASGs tagged `k8s.io/cluster-autoscaler/<cluster_name>=owned`. |
| `aws_load_balancer_controller` | `kube-system` / `aws-load-balancer-controller` | none | Upstream reference policy: manage ALBs/NLBs, target groups and security groups that the controller tags. |
| `external_dns` | `kube-system` / `external-dns` | `hosted_zone_ids` (**required**) | Change records only in the listed zones. List zones and records. |
| `external_secrets` | `external-secrets` / `external-secrets` | `secrets_manager_arns`, `ssm_parameter_arns`, `kms_key_arns` (at least one secret or parameter ARN is **required**) | Read only the listed secrets and parameters. Decrypt with the listed KMS keys. |

ARNs may use wildcards, for example `arn:aws:secretsmanager:us-east-1:111111111111:secret:dev/*`.
Add `kms_key_arns` only if those secrets use a customer-managed KMS key.

### Example

```hcl
module "identity" {
  source = "git::https://github.com/<org>/terraform-aws-identity.git?ref=v1.0.0"

  cluster_name      = var.cluster_name
  oidc_provider_arn = data.aws_iam_openid_connect_provider.this.arn

  cluster_autoscaler           = { enabled = true }
  aws_load_balancer_controller = { enabled = true }

  external_dns = {
    enabled         = true
    hosted_zone_ids = ["Z0123456789ABCDEFGHIJ"]
  }

  external_secrets = {
    enabled              = true
    secrets_manager_arns = ["arn:aws:secretsmanager:us-east-1:111111111111:secret:dev/*"]
  }
}
```

### Outputs

`cluster_autoscaler_role_arn`, `aws_load_balancer_controller_role_arn`, `external_dns_role_arn` and
`external_secrets_role_arn` each return the role's ARN, or `null` if that add-on is disabled.

## Connecting to Helm

Annotate each chart's service account with its role ARN. The chart's namespace and service account
name must match the module settings exactly. Always set the name explicitly: some charts (for
example `cluster-autoscaler`) generate a name from the release name by default.

| Chart | Values |
|---|---|
| `cluster-autoscaler` | `rbac.serviceAccount.name: cluster-autoscaler`<br>`rbac.serviceAccount.annotations."eks.amazonaws.com/role-arn"`<br>`autoDiscovery.clusterName: <cluster_name>` |
| `aws-load-balancer-controller` | `serviceAccount.name: aws-load-balancer-controller`<br>`serviceAccount.annotations."eks.amazonaws.com/role-arn"` |
| `external-dns` | `serviceAccount.name: external-dns`<br>`serviceAccount.annotations."eks.amazonaws.com/role-arn"` |
| `external-secrets` | `serviceAccount.name: external-secrets`<br>`serviceAccount.annotations."eks.amazonaws.com/role-arn"` |

```yaml
serviceAccount:
  name: external-dns
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::111111111111:role/dev-external-dns
```

Restart the pods after adding the annotation. The AWS credentials are injected when a pod starts.

## Common mistakes

| Symptom | Cause |
|---|---|
| `AccessDenied` on `AssumeRoleWithWebIdentity` | The chart's namespace or service account name doesn't match the module settings, or the annotation was added without restarting the pods. |
| Cluster Autoscaler sees the node group but never scales it | The ASG lacks the `k8s.io/cluster-autoscaler/<cluster_name>=owned` tag. EKS managed node groups add it automatically; self-managed groups need it added. |
| ExternalDNS logs `AccessDenied` for one domain | That hosted zone isn't in `hosted_zone_ids`. |
| `allowed_account_ids` error | Your credentials are for a different account than `account_id` in that environment folder's `main.tf`. |
| Controller breaks after a chart upgrade | Upstream added permissions. Compare the policy with the new release (see [Versions](#versions)). |

## Versions

| | Module | Root configurations (`examples/cluster1/<env>`) |
|---|---|---|
| Terraform | `>= 1.9.0, < 2.0.0` | `1.17.0` |
| AWS provider | `>= 6.0.0, < 7.0.0` | `6.70.0`, locked in each folder's `.terraform.lock.hcl` |

Pin the module by git tag (`?ref=vX.Y.Z`). The IAM policies match these upstream releases:
Cluster Autoscaler `v1.36.1` and AWS Load Balancer Controller `v3.6.2`. When you upgrade either
add-on, update its policy file (`cluster_autoscaler.tf` or `aws_load_balancer_controller.tf`) in the same PR.

## CI/CD

[`.github/workflows/terraform.yml`](.github/workflows/terraform.yml):

| Event | Runs |
|---|---|
| PR into `main` opened, reopened or updated with new commits | `fmt`, `validate`, then `plan` for every environment |
| Merge into `main` | `fmt`, `validate`, then `apply` to dev, then stg, then prd. Stops at the first failure. |

GitHub logs in to AWS through OIDC; the repo holds no AWS secrets. PR plans skip the state lock so
they never block an apply. At merge time, apply creates a new plan rather than reusing the PR's.

### One-time setup

1. **Branch protection on `main`:** require an approved PR, and require the `fmt`, `validate` and
   `plan` checks to pass. This is what limits applies to approved changes.
2. **GitHub environments:** each needs the variables `AWS_ROLE_ARN` and `AWS_REGION`.
   - `dev-plan`, `stg-plan`, `prd-plan`: unprotected, holding a read-only plan role.
   - `dev`, `stg`, `prd`: limited to the `main` branch, holding the apply role. Add required
     reviewers (at least on `prd`) if you want a manual sign-off before apply.
3. **In each AWS account:** register the IAM OIDC provider `token.actions.githubusercontent.com`
   (audience `sts.amazonaws.com`). Create two roles, each trusting a single GitHub environment
   through the `sub` claim:
   - Plan role: `repo:<org>/<repo>:environment:<env>-plan`. Read-only access plus the state bucket.
   - Apply role: `repo:<org>/<repo>:environment:<env>`. IAM write access plus the state bucket.

## Testing

Offline tests need no AWS access:

```sh
terraform init -backend=false
terraform test
```

## Not included

The EKS cluster and its OIDC provider, node groups, the CI roles and GitHub OIDC provider, and the
Helm releases are managed elsewhere.
