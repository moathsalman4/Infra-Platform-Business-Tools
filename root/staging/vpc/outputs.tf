output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "region" {
  description = "The AWS region where the VPC is deployed"
  value       = var.aws_region
}