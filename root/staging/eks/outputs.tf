output "aws_region" {
  description = "The AWS region where the EKS cluster is created."
  value       = var.aws_region
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "The Kubernetes API server endpoint URL"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = module.eks.cluster_version
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster, used to verify the API server's TLS connection"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for the cluster, used by IRSA roles in downstream modules"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the IAM OIDC provider, used in IRSA trust policy conditions"
  value       = module.eks.oidc_provider_url
}

output "node_role_arn" {
  description = "ARN of the IAM role attached to worker nodes"
  value       = module.eks.node_role_arn
}

output "ebs_csi_role_arn" {
  description = "ARN of the IRSA role for the EBS CSI driver"
  value       = module.eks.ebs_csi_role_arn
}

output "cluster_security_group_id" {
  description = "Security group ID for the EKS control plane"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID for the EKS worker nodes"
  value       = module.eks.node_security_group_id
}