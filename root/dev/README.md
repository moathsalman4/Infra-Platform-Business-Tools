# Dev Environment

The development environment configuration. Every push merged to `main` that touches `dev/vpc/` or `dev/eks/` files automatically applies via GitHub Actions.

## Components

| Component | Path | What it does |
|---|---|---|
| VPC | [`vpc/`](./vpc/) | Creates VPC, subnets, IGW, route tables for dev |
| EKS | [`eks/`](./eks/) | Creates EKS cluster, workers, addons in dev VPC |

## Apply Order

EKS depends on VPC. Always:

1. Apply VPC first (or ensure it's already up)
2. Then apply EKS

The CI workflows enforce this implicitly: EKS workflow's `terraform plan` will fail with "Unsupported attribute" errors if VPC remote state is empty.

## Destroy Order

Reverse of apply:

1. Destroy EKS first (`destroy-dev` workflow with target `dev/eks`)
2. Then destroy VPC (`destroy-dev` workflow with target `dev/vpc`)

The destroy workflow has a built-in safety check: it refuses to destroy `dev/vpc` while an EKS cluster named `main-cluster` still exists.

## Current Configuration

| Setting | Value | Where |
|---|---|---|
| VPC CIDR | `10.0.0.0/16` | `vpc/terraform.tfvars` |
| Subnet count | 3 (one per AZ) | `vpc/terraform.tfvars` |
| K8s version | 1.34 | `eks/terraform.tfvars` |
| Worker types | t3.medium, t3a.medium, t3.large, t3a.large | `eks/terraform.tfvars` |
| Desired workers | 3 | `eks/terraform.tfvars` |
| On-demand % | 100 (no spot, for stability) | `eks/terraform.tfvars` |

## Cost Estimate (Approximate)

When running:

| Resource | Cost |
|---|---|
| EKS control plane | ~$0.10/hour |
| 3x t3.medium on-demand | ~$0.125/hour combined |
| EBS gp3 (3 x 20GB) | ~$0.01/hour combined |
| **Total** | **~$0.24/hour while running** |

When destroyed: $0/hour (just pennies/year for S3 state bucket).

**Always destroy when not in use.**