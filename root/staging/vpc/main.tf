module "vpc" {
  source       = "../../../modules/vpc"
  cidr_block   = var.cidr_block
  env_name     = var.env_name
  subnet_count = var.subnet_count
  enable_nat   = var.enable_nat


}
# Deployed via CI/CD
