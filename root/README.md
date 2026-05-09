# Root Configurations

This directory contains the per-environment Terraform configurations. Each subdirectory under `root/{env}/{component}/` is its own independent Terraform root — meaning it has its own state file, its own `terraform init`, and its own backend configuration.

## Structure

```
root/
├── dev/                ✅ Active — fully implemented
│   ├── vpc/            VPC for dev
│   └── eks/            EKS cluster for dev
│
├── staging/            📋 Skeleton (empty files) — placeholder for future env
│   ├── vpc/
│   └── eks/
│
└── prod/               📋 Skeleton (empty files) — placeholder for future env
    ├── vpc/
    └── eks/
```

## Why Multiple Roots Per Environment?

We split each environment into separate roots (`vpc/` and `eks/`) for several reasons:

1. **Blast radius**: a bad EKS apply can't accidentally tear down VPC.
2. **Apply ordering**: VPC must exist before EKS plans (because EKS reads VPC remote state).
3. **Independent destroy**: you can destroy EKS without destroying VPC.
4. **Faster iteration**: a 30-second VPC plan vs a 60-second EKS plan when only one changed.

EKS reads VPC outputs via `terraform_remote_state`:

```hcl
# root/dev/eks/data.tf
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "moathsalman-tfstate-dev"
    key    = "env/dev/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

# root/dev/eks/main.tf
module "eks" {
  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.vpc.outputs.public_subnet_ids
}
```

## What's In Each Root

A typical root config has these files:

| File | Purpose |
|---|---|
| `backend.tf` | S3 backend configuration (bucket, key, region, locking) |
| `versions.tf` | Terraform + provider version constraints |
| `providers.tf` | Provider configurations (AWS region, default tags) |
| `variables.tf` | Input variable declarations |
| `terraform.tfvars` | Variable values for this specific environment |
| `main.tf` | Module instantiation — wires inputs to module |
| `outputs.tf` | Re-exposes module outputs as root outputs |
| `data.tf` | Data sources (for EKS roots: VPC remote state) |

## Promoting Changes Across Environments

The current model is "copy and adjust" — there's no shared state between environments. To roll out a tested change from dev to staging:

1. Verify change works in dev (CI applied it cleanly, no drift)
2. Replicate the same code/inputs in `root/staging/{component}/`
3. Push, plan, apply (with manual approval for non-dev — see prod environment notes)

This avoids the trap where a "shared" tfvars file forces you to roll changes everywhere at once.

## Environment-Specific Conventions

- **dev**: Smallest viable footprint. Public-only subnets for workers (no NAT). t3.medium workers. Auto-apply from CI on merge.
- **staging** (when implemented): Similar to dev but separate VPC, used for pre-prod validation.
- **prod** (when implemented): Larger instances, private worker subnets + NAT, **manual approval gate** before apply via GitHub Environments.