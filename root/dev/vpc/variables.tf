variable "cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "env_name" {
  type        = string
  description = "Environment name (dev, staging, prod) — used as resource name prefix"
}

variable "subnet_count" {
  type        = number
  default     = 3
  description = "Number of public/private subnet pairs to create across AZs"
}

variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
}