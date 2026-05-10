cluster_name    = "main-cluster"
cluster_version = "1.34"
workers_name    = "worker-node"
aws_region      = "us-east-1"
admin_role_arns = { sso_admin = "arn:aws:iam::665832051028:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_e23b6bc89fc39a38",
  cicd      = "arn:aws:iam::665832051028:role/GitHubActionsAppCICDRole",
  terraform = "arn:aws:iam::665832051028:role/GitHubActionsTerraformIAMrole"
}
instance_types                           = ["t3.medium", "t3a.medium", "t3.large", "t3a.large"]
min_size                                 = 1
max_size                                 = 5
desired_capacity                         = 3
on_demand_base_capacity                  = 0
on_demand_percentage_above_base_capacity = 20
node_disk_size_gb                        = 20
cicd_namespaces                          = ["default"]
tags                                     = { Project = "infra-platform-business-tools" }