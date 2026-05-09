# Terraform Modules

Reusable Terraform modules used by all environments under `root/`.

## Modules

### `vpc/`

Creates a VPC with public and private subnets across multiple availability zones, plus an internet gateway and route tables. Public subnets are tagged for ELB use; private subnets are tagged for internal ELB use — both ready for EKS to discover.

[See `modules/vpc/README.md` for full inputs/outputs.](./vpc/README.md)

### `eks/`

Creates an EKS cluster with self-managed worker nodes, OIDC provider, IRSA setup for EBS CSI, access entries for IAM/SSO/CI roles, and the four core EKS addons (vpc-cni, kube-proxy, coredns, aws-ebs-csi-driver).

[See `modules/eks/README.md` for full inputs/outputs.](./eks/README.md)

## How Modules Are Consumed

Root configurations under `root/{env}/{component}/` reference these modules with relative paths:

```hcl
module "vpc" {
  source       = "../../../modules/vpc"
  cidr_block   = var.cidr_block
  env_name     = var.env_name
  subnet_count = var.subnet_count
}
```

Same pattern for EKS:

```hcl
module "eks" {
  source       = "../../../modules/eks"
  vpc_id       = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids   = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  cluster_name = var.cluster_name
}
```

## Conventions

- Modules expose all configuration through variables — no hardcoded environment-specific values.
- Modules emit outputs for everything a downstream consumer might need.
- Modules use `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` (the modern resources), not the legacy inline `ingress`/`egress` blocks on `aws_security_group`.
- Modules pin no provider versions; pinning is done at the root level.

## Testing Changes To Modules

A change to `modules/eks/` will trigger the `eks-dev.yml` workflow (path filter includes `modules/eks/**`). Same for VPC. So:

1. Make module change on a feature branch
2. Open PR
3. The relevant workflow plans against `dev/`
4. Review plan in PR comment
5. Merge → applies to dev

If the change works in dev, replicate to staging/prod root configs separately.
