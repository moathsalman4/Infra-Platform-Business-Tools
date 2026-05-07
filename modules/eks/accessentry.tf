# PRINCIPAL 1: SSO ADMIN
# ------------------------------------------------------------
# Humans doing ops/break-glass work. Full cluster admin.

resource "aws_eks_access_entry" "sso_admin" {
  cluster_name      = aws_eks_cluster.main_cluster.name
  principal_arn     = var.admin_role_arns.sso_admin
  type              = "STANDARD"
  user_name         = "sso-admin:{{SessionName}}"
  kubernetes_groups = []
}

resource "aws_eks_access_policy_association" "sso_admin" {
  cluster_name  = aws_eks_cluster.main_cluster.name
  principal_arn = aws_eks_access_entry.sso_admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.sso_admin]
}


# PRINCIPAL 2: CI/CD ROLE (GitHub Actions Deploy)
# ------------------------------------------------------------
# Pipeline that deploys application workloads. Namespace-scoped.

resource "aws_eks_access_entry" "cicd" {
  cluster_name      = aws_eks_cluster.main_cluster.name
  principal_arn     = var.admin_role_arns.cicd
  type              = "STANDARD"
  user_name         = "github-actions-cicd"
  kubernetes_groups = []
}

resource "aws_eks_access_policy_association" "cicd" {
  cluster_name  = aws_eks_cluster.main_cluster.name
  principal_arn = aws_eks_access_entry.cicd.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = var.cicd_namespaces
  }

  depends_on = [aws_eks_access_entry.cicd]
}

# PRINCIPAL 3: TERRAFORM ROLE (GitHub Actions Terraform)
# ------------------------------------------------------------
# Role Terraform assumes to apply infra. Cluster-wide admin.
# Full admin needed because Terraform installs cluster-level
# things: EBS CSI driver service account, ingress controllers,
# CRDs, RBAC. Without admin, future Terraform plans on
# cluster-related K8s resources will fail.

resource "aws_eks_access_entry" "terraform" {
  cluster_name      = aws_eks_cluster.main_cluster.name
  principal_arn     = var.admin_role_arns.terraform
  type              = "STANDARD"
  user_name         = "github-actions-terraform"
  kubernetes_groups = []
}

resource "aws_eks_access_policy_association" "terraform" {
  cluster_name  = aws_eks_cluster.main_cluster.name
  principal_arn = aws_eks_access_entry.terraform.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.terraform]
}

# Personal admin access for the developer's IAM user
resource "aws_eks_access_entry" "iam_admin" {
  cluster_name  = aws_eks_cluster.main_cluster.name
  principal_arn = "arn:aws:iam::665832051028:user/salman_practice"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "iam_admin" {
  cluster_name  = aws_eks_cluster.main_cluster.name
  principal_arn = aws_eks_access_entry.iam_admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# Worker node bootstrap access entry
# Required so kubelet can register nodes with the cluster API.
# EC2_LINUX type implicitly grants system:nodes group permissions.
resource "aws_eks_access_entry" "worker_nodes" {
  cluster_name  = aws_eks_cluster.main_cluster.name
  principal_arn = aws_iam_role.workers_role.arn
  type          = "EC2_LINUX"
}