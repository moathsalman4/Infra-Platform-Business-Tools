# CI/CD Workflows

GitHub Actions workflows that drive infrastructure changes. **All changes go through CI** — the goal is that nobody runs `terraform apply` from their laptop in production.

## Workflows

| File | Trigger | Purpose |
|---|---|---|
| [`vpc-dev.yml`](./vpc-dev.yml) | PR + push to `main` (path-filtered) | Plan-on-PR, apply-on-merge for VPC dev |
| [`eks-dev.yml`](./eks-dev.yml) | PR + push to `main` (path-filtered) | Plan-on-PR, apply-on-merge for EKS dev |
| [`destroy-dev.yml`](./destroy-dev.yml) | `workflow_dispatch` only | Manual destroy of dev VPC or EKS |

## Authentication

All workflows use **OIDC** to assume `GitHubActionsTerraformIAMrole` in AWS. No static AWS credentials are stored in GitHub Secrets.

```yaml
permissions:
  id-token: write   # required for OIDC token request
  contents: read    # required for actions/checkout

# ...

- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::665832051028:role/GitHubActionsTerraformIAMrole
    aws-region: us-east-1
    role-session-name: gha-...-${{ github.run_id }}
```

The trust policy on `GitHubActionsTerraformIAMrole` only allows assumption from this specific repo (`moathsalman4/Infra-Platform-Business-Tools`), so a fork can't authenticate.

## Apply Workflow Pattern (vpc-dev.yml, eks-dev.yml)

```
                      ┌─ pull_request to main ─► terraform plan
                      │                          + post comment on PR
File changes triggers ┤
(via path filter)     │
                      └─ push to main ────────► terraform apply -auto-approve
```

Both workflows share the same step structure:

1. **Print event info** — diagnostic
2. **Checkout** — clone the repo
3. **Configure AWS credentials** — OIDC handshake
4. **Verify AWS auth** — `aws sts get-caller-identity`
5. **Setup Terraform** — install correct version
6. **Format check** — `terraform fmt -check -recursive`
7. **Init** — backend + providers
8. **Validate** — syntax/reference check
9. **Plan** — compute diff (continue-on-error so comment can post)
10. **Comment plan on PR** — only on `pull_request` events
11. **Plan status** — re-fail if plan failed (cleanup of step 9's continue-on-error)
12. **Apply** — only on `push` to `main`

### Path filters

Each workflow only triggers when relevant files change:

```yaml
# vpc-dev.yml
paths:
  - 'modules/vpc/**'
  - 'root/dev/vpc/**'
  - '.github/workflows/vpc-dev.yml'

# eks-dev.yml
paths:
  - 'modules/eks/**'
  - 'root/dev/eks/**'
  - '.github/workflows/eks-dev.yml'
```

A README change won't trigger any workflow. An EKS change won't trigger the VPC plan.

## Destroy Workflow (destroy-dev.yml)

Manually triggered via the **Actions tab → Destroy Dev (Manual) → Run workflow**.

### Inputs

| Input | Type | Description |
|---|---|---|
| `target` | choice (`dev/vpc` or `dev/eks`) | Which environment to destroy |
| `confirm` | string (must equal `destroy`) | Forces explicit intent |

### Safety mechanisms

1. **Confirmation phrase**: must literally type `destroy` (case-sensitive). Anything else fails the run.
2. **Safety check**: when `target == dev/vpc`, the workflow runs `aws eks list-clusters` and refuses to proceed if `main-cluster` exists. Destroying VPC while EKS is alive would orphan the cluster's networking.
3. **Manual trigger only**: no `push:` or `pull_request:` triggers. The workflow file's existence does nothing — it must be invoked explicitly.

### Why a separate destroy workflow?

Destroy is destructive and asymmetric:
- Apply-on-merge is fine: a bad plan can be caught at PR review.
- Destroy-on-merge would be terrifying: a misclick or an accidental merge could nuke production.

A manual trigger with a confirmation phrase is the right level of friction for this operation.

## Common Issues

### "Could not assume role with OIDC"

Possible causes:
- Trust policy missing `id-token: write` permission in workflow
- Trust policy `sub` filter doesn't match the workflow's context (wrong repo, wrong branch pattern)
- Session name has invalid characters (must match `[\w+=,.@-]*` — **no slashes**)

### "Unsupported attribute" on EKS plan

Means VPC remote state is missing or empty. Either:
- VPC was never applied — apply VPC first
- VPC was destroyed — re-apply VPC, or skip EKS until VPC is back

### Plan succeeds locally but fails in CI

Usually one of:
- A `.tfvars` file isn't formatted (CI's `fmt -check` fails)
- Provider lock file doesn't match (run `terraform init -upgrade` locally and commit the lockfile)
- Local state is out of sync with S3 backend (rare, but possible if someone applied locally)

## Modifying Workflows

When changing a workflow file:

1. Test on a feature branch first
2. The workflow's **path filter includes itself** — so changing the workflow file triggers a run
3. PR plan tells you whether your change broke anything

Workflow YAML is unforgiving. Common gotchas:
- `${{ ... }}` is expression syntax — not valid Bash
- GitHub Actions has a small set of expression functions; `replace()` does **not** exist
- For string manipulation, use a `run:` step with bash + `$GITHUB_OUTPUT`
- `working-directory` cannot reference unchecked-out paths — override with `working-directory: .` for early steps