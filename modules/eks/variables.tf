variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.34"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs where the EKS cluster ENIs will be placed"
}

variable "worker_subnet_ids" {
  type        = list(string)
  default     = null
  nullable    = true
  description = "for the ASG, optional, falls back to subnet_ids"
}

variable "workers_name" {
  description = "The name of the EKS worker nodes."
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID where the EKS cluster will be deployed."
  type        = string
}

variable "admin_role_arns" {
  description = "IAM role ARNs for the 3 principals needing cluster access."
  type = object({
    sso_admin = string # SSO Permission Set role
    cicd      = string # GitHub Actions deploy role
    terraform = string # GitHub Actions Terraform role
  })
}

variable "cicd_namespaces" {
  type        = list(string)
  default     = ["default"]
  description = "Kubernetes namespaces the CI/CD role can edit."
}

variable "node_disk_size_gb" {
  type        = number
  default     = 20
  description = "Size of EBS volume for each worker node (in GB)."
}

variable "instance_types" {
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
  description = "Instance types for worker nodes (used by ASG mixed instances policy)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to apply to all resources in the EKS module. Tags will be inherited by all child resources, and can be overridden at the resource level if needed."
}

variable "min_size" {
  type        = number
  default     = 1
  description = "Minimum number of worker nodes in the Auto Scaling Group."
}

variable "max_size" {
  type        = number
  default     = 5
  description = "Maximum number of worker nodes in the Auto Scaling Group."
}

variable "desired_capacity" {
  type        = number
  default     = 3
  description = "Desired number of worker nodes in the Auto Scaling Group."
}

variable "on_demand_base_capacity" {
  type        = number
  default     = 0
  description = "Number of on-demand instances to use before starting to provision spot instances (used in ASG mixed instances policy)"
}

variable "on_demand_percentage_above_base_capacity" {
  type        = number
  default     = 20
  description = "Percentage of on-demand instances to use above the base capacity (used in ASG mixed instances policy)"
}