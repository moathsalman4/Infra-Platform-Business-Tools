# EKS Module

Creates a complete, production-style EKS cluster with self-managed worker nodes, IRSA, addons, and access entries.

## Resources Created

Approximately **33 resources** when fully deployed. Major categories:

### Cluster

| Resource | Notes |
|---|---|
| `aws_eks_cluster.main_cluster` | k8s 1.34, public endpoint, `API_AND_CONFIG_MAP` auth, **no creator admin permissions** |
| `aws_iam_role.cluster_role` | EKS service role with `AmazonEKSClusterPolicy` |

### Workers (Self-Managed via ASG)

| Resource | Notes |
|---|---|
| `aws_iam_role.workers_role` | Attached: WorkerNode, CNI, ECR-RO, SSMManagedInstanceCore |
| `aws_iam_instance_profile.worker_node` | For workers role |
| `aws_launch_template.workers` | AL2023, t3.medium base, gp3 20GB EBS, IMDSv2, AL2023 nodeadm bootstrap |
| `aws_autoscaling_group.workers` | Mixed-instances policy, configurable on-demand %, lifecycle ignore_changes |

### Networking

| Resource | Notes |
|---|---|
| `aws_security_group.node_sg` | Worker node SG (the only manually-created SG) |
| 5x `aws_vpc_security_group_ingress_rule` | node↔node, kubelet from cluster, HTTPS from cluster, HTTPS from nodes (the critical one), node↔node |
| 1x `aws_vpc_security_group_egress_rule` | All outbound |

The **EKS-managed cluster SG** is referenced via `aws_eks_cluster.main_cluster.vpc_config[0].cluster_security_group_id`. The module doesn't create a separate cluster SG — EKS auto-creates one and we wire rules to it. (See "Bug history" in repo root README.)

### IRSA (IAM Roles for Service Accounts)

| Resource | Notes |
|---|---|
| `aws_iam_openid_connect_provider.eks_oidc` | OIDC provider for the cluster |
| `aws_iam_role.ebs_csi_driver` | IRSA role for `system:serviceaccount:kube-system:ebs-csi-controller-sa` |
| Policy attachment | `AmazonEBSCSIDriverPolicy` |

### Access Entries (the modern auth model — no `aws-auth` ConfigMap)

| Entry | Type | Policy | Purpose |
|---|---|---|---|
| `sso_admin` | STANDARD | `AmazonEKSClusterAdminPolicy` | SSO admin access |
| `cicd` | STANDARD | `AmazonEKSEditPolicy` | CI/CD app deploys |
| `terraform` | STANDARD | `AmazonEKSClusterAdminPolicy` | Terraform role admin |
| `worker_nodes` | EC2_LINUX | (none) | **Required** for kubelet auth |
| `iam_admin` | STANDARD | `AmazonEKSClusterAdminPolicy` | Local CLI access for IAM user |

Without `worker_nodes` (EC2_LINUX type), kubelets cannot authenticate and nodes never join.

### Addons

| Addon | Notes |
|---|---|
| `vpc-cni` | Pod networking |
| `kube-proxy` | Service routing |
| `coredns` | DNS — depends on ASG (needs nodes to schedule) |
| `aws-ebs-csi-driver` | Persistent volumes — depends on ASG + IRSA role |

`resolve_conflicts_on_create = "OVERWRITE"`, `resolve_conflicts_on_update = "PRESERVE"`.

## Inputs

| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `cluster_name` | string | yes | — | EKS cluster name |
| `cluster_version` | string | yes | — | k8s minor version (e.g., `"1.34"`) |
| `workers_name` | string | yes | — | Prefix for worker IAM/ASG/LT resources |
| `vpc_id` | string | yes | — | VPC to deploy into |
| `subnet_ids` | list(string) | yes | — | Subnet IDs for cluster + workers |
| `instance_types` | list(string) | yes | — | Worker instance types (mixed-instances policy) |
| `min_size` | number | yes | — | ASG minimum |
| `max_size` | number | yes | — | ASG maximum |
| `desired_capacity` | number | yes | — | ASG desired count |
| `on_demand_base_capacity` | number | yes | — | Number of base on-demand instances |
| `on_demand_percentage_above_base_capacity` | number | yes | — | % on-demand above base (100 = no spot) |
| `node_disk_size_gb` | number | no | `20` | EBS root volume size for workers |
| `admin_role_arns` | object | yes | — | Map of {sso_admin, cicd, terraform, iam_admin} ARNs for access entries |
| `cicd_namespaces` | list(string) | no | `["default"]` | Namespaces the CICD access entry can edit |
| `tags` | map(string) | no | `{}` | Common tags applied to taggable resources |

## Outputs

| Name | Description |
|---|---|
| `cluster_name` | Cluster name |
| `cluster_arn` | Cluster ARN |
| `cluster_endpoint` | API server endpoint URL |
| `cluster_version` | Active k8s version |
| `cluster_ca_certificate` | (sensitive) Base64-encoded CA cert |
| `cluster_security_group_id` | EKS-managed cluster SG ID (NOT a manually-created one) |
| `node_security_group_id` | Worker node SG ID |
| `oidc_provider_arn` | IRSA OIDC provider ARN |
| `oidc_provider_url` | IRSA OIDC provider URL |
| `node_role_arn` | Worker IAM role ARN |
| `ebs_csi_role_arn` | EBS CSI IRSA role ARN |

## Usage

```hcl
module "eks" {
  source = "../../../modules/eks"

  cluster_name    = "main-cluster"
  cluster_version = "1.34"
  workers_name    = "worker-node"

  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.vpc.outputs.public_subnet_ids

  instance_types                           = ["t3.medium", "t3a.medium", "t3.large", "t3a.large"]
  min_size                                 = 1
  max_size                                 = 5
  desired_capacity                         = 3
  on_demand_base_capacity                  = 0
  on_demand_percentage_above_base_capacity = 100

  admin_role_arns = {
    sso_admin = "arn:aws:iam::ACCOUNT:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_..."
    cicd      = "arn:aws:iam::ACCOUNT:role/GitHubActionsAppCICDRole"
    terraform = "arn:aws:iam::ACCOUNT:role/GitHubActionsTerraformIAMrole"
    iam_admin = "arn:aws:iam::ACCOUNT:user/your-user"
  }

  tags = { Project = "my-project" }
}
```

## Critical Implementation Details (Don't Change Without Reading This)

### 1. Launch Template metadata options

```hcl
metadata_options {
  http_endpoint               = "enabled"
  http_tokens                 = "required"
  http_put_response_hop_limit = 1
  instance_metadata_tags      = "disabled"
}
```

`instance_metadata_tags = "disabled"` is **required**. With it enabled, AWS forbids `/` in tag values, breaking all `kubernetes.io/...` tags. The cluster fails to launch.

### 2. AL2023 user data (nodeadm)

The launch template's `user_data` is a MIME multipart document with a `node.eks.aws/v1alpha1` NodeConfig. AL2 user-data scripts (`/etc/eks/bootstrap.sh`) do not work on AL2023.

### 3. Cluster SG references

All node SG rules reference `aws_eks_cluster.main_cluster.vpc_config[0].cluster_security_group_id`. **Don't** create a separate cluster SG — EKS auto-creates one and ignores any manually-created one (see bug history in root README).

### 4. ASG `lifecycle.ignore_changes`

```hcl
lifecycle {
  ignore_changes = [desired_capacity]
}
```

This lets the cluster autoscaler (or a human) adjust desired_capacity at runtime without terraform fighting back on the next apply.

### 5. Worker access entry

```hcl
resource "aws_eks_access_entry" "worker_nodes" {
  cluster_name  = aws_eks_cluster.main_cluster.name
  principal_arn = aws_iam_role.workers_role.arn
  type          = "EC2_LINUX"
}
```

Without this, nodes never become Ready.
