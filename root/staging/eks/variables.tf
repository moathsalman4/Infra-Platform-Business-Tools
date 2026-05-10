variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.34"
}

variable "workers_name" {
  description = "The name of the EKS worker nodes."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where the EKS cluster will be created."
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

variable "instance_types" {
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
  description = "Instance types for worker nodes (used by ASG mixed instances policy)"
}

variable "node_disk_size_gb" {
  type        = number
  default     = 20
  description = "Size of EBS volume for each worker node (in GB)."
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
  description = "Number of on-demand instances to maintain in the Auto Scaling Group. Setting this to a value greater than 0 will create a separate ASG for on-demand instances, and the main ASG will be configured with a mixed instances policy to use spot instances only."
}

variable "on_demand_percentage_above_base_capacity" {
  type        = number
  default     = 20
  description = "Percentage of on-demand instances to use above the base capacity (used in ASG mixed instances policy). For example, if on_demand_base_capacity is set to 2 and this value is set to 50, then when the ASG needs to scale above 2 instances, it will try to maintain an equal percentage of on-demand and spot instances (e.g. 3 on-demand and 3 spot for a total of 6 instances)."
}

variable "worker_subnet_ids" {
  type     = list(string)
  default  = null
  nullable = true
  description = "for the ASG, optional, falls back to subnet_ids"
}