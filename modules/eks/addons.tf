# ===== Version data sources =====
data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.main_cluster.version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.main_cluster.version
  most_recent        = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.main_cluster.version
  most_recent        = true
}

data "aws_eks_addon_version" "ebs_csi" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = aws_eks_cluster.main_cluster.version
  most_recent        = true
}

# ===== Add-on resources ===== 
#vpc-cni is what allows your worker nodes to get IP addresses from the VPC and talk to each other.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main_cluster.name
  addon_name                  = "vpc-cni"
  addon_version               = data.aws_eks_addon_version.vpc_cni.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = var.tags
}

#kube-proxy is what allows your worker nodes to talk to the Kubernetes API and each other. It's responsible for routing traffic to the correct pods and services within the cluster.
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main_cluster.name
  addon_name                  = "kube-proxy"
  addon_version               = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = var.tags
}

#coredns is what allows your worker nodes to resolve DNS names within the cluster. It's responsible for providing DNS resolution for services and pods within the cluster.
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main_cluster.name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = var.tags

  depends_on = [aws_autoscaling_group.workers]
}

#aws-ebs-csi-driver is what allows your worker nodes to use EBS volumes as persistent storage for your applications. It's responsible for managing the lifecycle of EBS volumes and attaching/detaching them to/from worker nodes as needed.
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.main_cluster.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.ebs_csi.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  service_account_role_arn    = aws_iam_role.ebs_csi_driver.arn
  tags                        = var.tags

  depends_on = [
    aws_autoscaling_group.workers,
    aws_iam_openid_connect_provider.eks_oidc,
  ]
}