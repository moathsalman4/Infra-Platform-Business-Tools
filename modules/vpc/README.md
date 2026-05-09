# VPC Module

Creates a VPC suitable for hosting an EKS cluster, with public and private subnets distributed across multiple availability zones.

## Resources Created

| Resource | Count | Notes |
|---|---|---|
| `aws_vpc` | 1 | DNS hostnames + DNS support enabled |
| `aws_subnet.public` | N (var.subnet_count) | One per AZ, `map_public_ip_on_launch = true` |
| `aws_subnet.private` | N (var.subnet_count) | One per AZ, no public IP |
| `aws_internet_gateway` | 1 | Attached to VPC |
| `aws_route_table.public` | 1 | Default route via IGW |
| `aws_route_table.private` | 1 | No default route (VPC-local only — no NAT yet) |
| `aws_route_table_association.public` | N | Associates public subnets to public RT |
| `aws_route_table_association.private` | N | Associates private subnets to private RT |

## CIDR Layout

For a `cidr_block = "10.0.0.0/16"` and `subnet_count = 3`:

| Subnet | CIDR | AZ |
|---|---|---|
| public[0] | 10.0.1.0/24 | 1st AZ |
| public[1] | 10.0.2.0/24 | 2nd AZ |
| public[2] | 10.0.3.0/24 | 3rd AZ |
| private[0] | 10.0.10.0/24 | 1st AZ |
| private[1] | 10.0.11.0/24 | 2nd AZ |
| private[2] | 10.0.12.0/24 | 3rd AZ |

CIDRs are computed dynamically with `cidrsubnet()`, so any /16 base block works.

## Kubernetes Subnet Tags

Public subnets get `kubernetes.io/role/elb = 1` so internet-facing services can use them automatically.
Private subnets get `kubernetes.io/role/internal-elb = 1` for internal LBs.

These tags let EKS auto-discover where to place load balancers without per-cluster configuration.

## Inputs

| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `cidr_block` | string | yes | — | The /16 CIDR for the VPC (e.g., `10.0.0.0/16`) |
| `env_name` | string | yes | — | Used as resource name prefix (e.g., `dev`, `staging`, `prod`) |
| `subnet_count` | number | no | `3` | Number of public/private subnet pairs to create across AZs |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | The VPC ID |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs |
| `vpc_cidr_block` | The VPC's CIDR block |

## Usage

```hcl
module "vpc" {
  source = "../../../modules/vpc"

  cidr_block   = "10.0.0.0/16"
  env_name     = "dev"
  subnet_count = 3
}
```

## Notes & Gotchas

- **No NAT gateway** — private subnets have no internet egress. For EKS, this is fine because we put workers in public subnets currently. If you move workers to private subnets, add a NAT gateway (one per AZ for HA, or one shared for cost).
- **`subnet_count` must not exceed available AZs** in the region. `us-east-1` has 6 AZs, so 3 is safe.
- The module uses `cidrsubnet(vpc_cidr, 8, count.index + offset)` — public subnets start at offset 1, private at offset 10. Don't change this without considering CIDR conflicts.
