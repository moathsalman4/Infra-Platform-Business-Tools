output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.main_cluster.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main_cluster.arn
}

output "cluster_endpoint" {
  description = "The Kubernetes API server endpoint URL"
  value       = aws_eks_cluster.main_cluster.endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = aws_eks_cluster.main_cluster.version
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster, used to verify the API server's TLS connection"
  value       = aws_eks_cluster.main_cluster.certificate_authority[0].data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for the cluster, used by IRSA roles in downstream modules"
  value       = aws_iam_openid_connect_provider.eks_oidc.arn
}

output "oidc_provider_url" {
  description = "URL of the IAM OIDC provider, used in IRSA trust policy conditions"
  value       = aws_iam_openid_connect_provider.eks_oidc.url
}

output "node_role_arn" {
  description = "ARN of the IAM role attached to worker nodes"
  value       = aws_iam_role.workers_role.arn
}

output "ebs_csi_role_arn" {
  description = "ARN of the IRSA role for the EBS CSI driver"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "cluster_security_group_id" {
  description = "Security group ID for the EKS control plane"
  value       = aws_security_group.cluster_sg.id
}

output "node_security_group_id" {
  description = "Security group ID for the EKS worker nodes"
  value       = aws_security_group.node_sg.id
}