# Infra-Platform-Business-Tools

AWS infrastructure-as-code for a multi-environment platform built on **EKS (Kubernetes 1.34)** running on **AL2023** worker nodes. All deployments flow through **GitHub Actions CI/CD** with **OIDC authentication** — no static AWS credentials anywhere.

---

## What's In This Repo

```
.
├── modules/                 # Reusable Terraform modules
│   ├── vpc/                 # VPC + public/private subnets + IGW + route tables
│   └── eks/                 # EKS cluster + workers + IRSA + addons
│
├── root/                    # Root configurations per environment
│   ├── dev/
│   │   ├── vpc/             # ✅ Active — wires VPC module for dev
│   │   └── eks/             # ✅ Active — wires EKS module for dev
│   ├── staging/             # 📋 Skeleton (empty) — for future use
│   └── prod/                # 📋 Skeleton (empty) — for future use
│
├── .github/workflows/       # CI/CD pipelines
│   ├── vpc-dev.yml          # Plan on PR, apply on merge — VPC dev
│   ├── eks-dev.yml          # Plan on PR, apply on merge — EKS dev
│   └── destroy-dev.yml      # Manual workflow_dispatch — destroy dev resources
│
└── README.md                # You are here
```

Each directory has its own README explaining what it contains.

---

## Architecture

```
                     ┌──────────────────────────────────────┐
                     │       GitHub (this repo)             │
                     │                                      │
                     │  feature/* branch ──► PR ──► main    │
                     │           │            │       │     │
                     │       (no plan)   (plan +    (apply) │
                     │                    comment)          │
                     └──────────────────┬───────────────────┘
                                        │
                                        │ OIDC (no static creds)
                                        ▼
                     ┌──────────────────────────────────────┐
                     │         AWS Account                  │
                     │                                      │
                     │   IAM Role: GitHubActionsTerraform   │
                     │           │                          │
                     │           ▼                          │
                     │   S3 backend (state) ◄──┐            │
                     │           │             │            │
                     │           ▼             │            │
                     │   ┌───────────────┐     │            │
                     │   │ VPC (dev)     │     │            │
                     │   │  10.0.0.0/16  │     │            │
                     │   │               │     │            │
                     │   │  ┌─────────┐  │     │            │
                     │   │  │ EKS     │──┼─────┘            │
                     │   │  │ cluster │  │                  │
                     │   │  │  + 3    │  │                  │
                     │   │  │ workers │  │                  │
                     │   │  └─────────┘  │                  │
                     │   └───────────────┘                  │
                     └──────────────────────────────────────┘
```

### Networking layout (VPC)

```
VPC: 10.0.0.0/16 (us-east-1)

Public subnets (k8s tag: kubernetes.io/role/elb=1)
  10.0.1.0/24  (us-east-1a)
  10.0.2.0/24  (us-east-1b)
  10.0.3.0/24  (us-east-1c)

Private subnets (k8s tag: kubernetes.io/role/internal-elb=1)
  10.0.10.0/24 (us-east-1a)
  10.0.11.0/24 (us-east-1b)
  10.0.12.0/24 (us-east-1c)

  Public  ──► Internet Gateway ──► Internet
  Private ──► (VPC-local only, no NAT yet)
```

### EKS topology

```
EKS Cluster (main-cluster, k8s 1.34)
  ├─ Control plane (managed by AWS)
  ├─ OIDC provider (for IRSA)
  ├─ 5 access entries
  │   ├─ sso_admin       (AdministratorAccess)
  │   ├─ cicd            (Edit policy)
  │   ├─ terraform       (AdministratorAccess)
  │   ├─ worker_nodes    (EC2_LINUX type, no policy)
  │   └─ iam_admin       (AdministratorAccess for local CLI)
  ├─ ASG: 3 workers (t3.medium, on-demand, AL2023)
  └─ Addons: vpc-cni, kube-proxy, coredns, aws-ebs-csi-driver
```

---

## Quick Start

### Prerequisites

- AWS CLI configured (`aws configure`)
- `terraform` 1.13.3 (matches CI version)
- `kubectl`
- Git push access to this repo

### Deploy dev environment

```bash
# 1. Create a feature branch
git checkout -b feature/your-change

# 2. Make changes in root/dev/vpc/ or root/dev/eks/
# (modify .tfvars or module inputs)

# 3. Push and open PR
git add .
git commit -m "Your change"
git push -u origin feature/your-change

# 4. Open PR on GitHub
#    - Workflow runs `terraform plan`
#    - Plan posted as a comment on the PR
#    - Review the plan

# 5. Merge to main
#    - Workflow runs `terraform apply -auto-approve`
#    - VPC: ~30s, EKS: ~15-20 min
```

### Connect kubectl to EKS

```bash
aws eks update-kubeconfig --name main-cluster --region us-east-1
kubectl get nodes
```

### Destroy dev environment

Via GitHub UI:

1. Go to **Actions** → **Destroy Dev (Manual)**
2. Click **Run workflow**
3. Select target (`dev/vpc` or `dev/eks`)
4. Type `destroy` to confirm
5. Click **Run workflow**

The workflow includes a safety check: it will refuse to destroy `dev/vpc` if `dev/eks` is still alive (would orphan the cluster's networking).

**Always destroy `dev/eks` first, then `dev/vpc`.**

---

## CI/CD Authentication

All AWS access from GitHub Actions uses **OIDC** — no long-lived access keys.

### Trust setup

- IAM role: `GitHubActionsTerraformIAMrole` (has `AdministratorAccess`)
- Trust policy allows `sts:AssumeRoleWithWebIdentity` from this repo only
- Subject filter: `repo:moathsalman4/Infra-Platform-Business-Tools:ref:refs/heads/*` and `repo:.../...:pull_request`
- IAM OIDC provider: `arn:aws:iam::665832051028:oidc-provider/token.actions.githubusercontent.com`

### How it works at runtime

```
1. Runner starts → asks GitHub for an OIDC JWT
2. JWT contains: { repo, branch/PR, run_id, ... }
3. Runner sends JWT to AWS STS
4. AWS validates JWT against role trust policy
5. AWS returns ~1-hour temp credentials
6. terraform commands run with those creds
```

If you fork this repo, the trust policy will reject your tokens — by design.

---

## Lessons Learned & Bugs Fixed

This repo went through several real-world bugs. They're documented here so future-you (or anyone using this as a reference) can avoid them.

### 1. AL2 EKS AMIs were retired in November 2025

EKS no longer publishes Amazon Linux 2 optimized AMIs. The module uses **AL2023** with `nodeadm` bootstrap (MIME multipart user-data via `node.eks.aws/v1alpha1` config). See `modules/eks/lt.tf`.

### 2. IMDS instance metadata tags break Kubernetes labels

When `instance_metadata_tags` is enabled on a launch template, AWS forbids `/` in tag values. Kubernetes uses `kubernetes.io/cluster/...` tags everywhere → cluster fails to launch.

**Fix**: explicitly set `instance_metadata_tags = "disabled"` in the LT's `metadata_options` block. Omitting it is not enough; AWS defaults can vary.

### 3. EKS cluster security group references

The EKS module originally created its own `aws_security_group.cluster_sg` and used that in node SG ingress rules. **EKS ignores any manually-created cluster SG and auto-creates its own** (exposed via `aws_eks_cluster.X.vpc_config[0].cluster_security_group_id`). The result:

- Pods couldn't reach `172.20.0.1:443` (in-cluster API service) → CoreDNS, EBS CSI, etc. all crashlooping
- Control plane couldn't reach kubelet on port 10250 → `kubectl logs` timed out

**Fix**: removed the manually-created `cluster_sg` resource. All SG rules now reference EKS's auto-created SG via `aws_eks_cluster.main_cluster.vpc_config[0].cluster_security_group_id`. See `modules/eks/sg.tf`.

### 4. Worker nodes need an EC2_LINUX access entry

Without an explicit `aws_eks_access_entry` of type `EC2_LINUX`, kubelets can't authenticate, nodes never join, and addon pods stay unscheduled. See `modules/eks/accessentry.tf`.

### 5. `replace()` is not a GitHub Actions expression function

GitHub Actions has `contains()`, `startsWith()`, `format()`, etc. but **no `replace()`**. To do string replacement, use a `run:` step with bash parameter expansion (`${VAR//pattern/replacement}`) and write the result to `$GITHUB_OUTPUT`. See the "Compute session name" step in `.github/workflows/destroy-dev.yml`.

### 6. AWS session names can't contain `/`

`roleSessionName` must match `[\w+=,.@-]*`. Inputs like `dev/vpc` need to be transformed (we use `dev-vpc`) before being passed as session names.

### 7. `.terraform/` provider binaries blow up the repo

`terraform init` downloads ~700MB of provider binaries into `.terraform/`. Without a `.gitignore`, these get committed and exceed GitHub's 100MB file size limit. **Always commit a `.gitignore` first.** See `.gitignore` at repo root.

### 8. `git rm --cached` doesn't remove from history

If big files are already committed, `git rm --cached` only removes them from new commits. To remove from history before pushing, use `git rebase -i origin/main` and squash the offending commits, dropping the files entirely.

---

## State Backend

| Setting | Value |
|---|---|
| Type | S3 with native locking |
| Bucket | `moathsalman-tfstate-dev` |
| Region | `us-east-1` |
| Encryption | enabled |
| Locking | `use_lockfile = true` (S3-native, no DynamoDB) |
| Keys | `env/{env}/{component}/terraform.tfstate` |

Examples:
- `env/dev/vpc/terraform.tfstate`
- `env/dev/eks/terraform.tfstate`

---

## Repo Conventions

- **Branching**: `feature/*` for changes, PR to `main`, merge triggers apply.
- **Commit style**: brief imperative subject line (`Add X`, `Fix Y`).
- **No direct commits to main** for infra changes (workflow file fixes are the exception during early bootstrap).
- **Provider lockfiles** (`.terraform.lock.hcl`) are committed.
- **Provider binaries** (`.terraform/`) are gitignored.

---

## Contact / Owner

Repo owner: `@moathsalman4`
