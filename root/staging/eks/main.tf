module "eks" {
  source                                   = "../../../modules/eks"
  cluster_name                             = var.cluster_name
  cluster_version                          = var.cluster_version
  workers_name                             = var.workers_name
  vpc_id                                   = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids                               = concat(data.terraform_remote_state.vpc.outputs.public_subnet_ids, data.terraform_remote_state.vpc.outputs.private_subnet_ids)
  worker_subnet_ids                        = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  admin_role_arns                          = var.admin_role_arns
  cicd_namespaces                          = var.cicd_namespaces
  instance_types                           = var.instance_types
  min_size                                 = var.min_size
  max_size                                 = var.max_size
  desired_capacity                         = var.desired_capacity
  on_demand_base_capacity                  = var.on_demand_base_capacity
  on_demand_percentage_above_base_capacity = var.on_demand_percentage_above_base_capacity
  node_disk_size_gb                        = var.node_disk_size_gb
  tags                                     = var.tags

}