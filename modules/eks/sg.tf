# Worker node security group
# This is the only SG we explicitly create — the cluster SG is auto-created by EKS
resource "aws_security_group" "node_sg" {
  name        = "${var.cluster_name}-node-sg"
  description = "EKS worker node security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.cluster_name}-node-sg"
  }
}

# INGRESS: node ↔ node (all traffic between worker nodes)
resource "aws_vpc_security_group_ingress_rule" "nodes_internal" {
  security_group_id            = aws_security_group.node_sg.id
  referenced_security_group_id = aws_security_group.node_sg.id
  ip_protocol                  = "-1"
  description                  = "Allow all node-to-node traffic"
}

# INGRESS: EKS-managed cluster SG → kubelet on nodes (kubectl logs/exec, metrics-server)
resource "aws_vpc_security_group_ingress_rule" "nodes_from_cluster_kubelet" {
  security_group_id            = aws_security_group.node_sg.id
  referenced_security_group_id = aws_eks_cluster.main_cluster.vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  description                  = "Allow EKS control plane to reach kubelet on nodes"
}

# INGRESS: EKS-managed cluster SG → nodes on 443 (extension API servers, admission webhooks)
resource "aws_vpc_security_group_ingress_rule" "nodes_from_cluster_https" {
  security_group_id            = aws_security_group.node_sg.id
  referenced_security_group_id = aws_eks_cluster.main_cluster.vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Allow control plane HTTPS to nodes (webhooks)"
}

# INGRESS: nodes → EKS-managed cluster SG on 443 (in-cluster API access)
# This is the rule that was missing — pods need to reach 172.20.0.1:443 through this path
resource "aws_vpc_security_group_ingress_rule" "cluster_https_from_nodes" {
  security_group_id            = aws_eks_cluster.main_cluster.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.node_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Allow nodes to reach Kubernetes API"
}

# EGRESS: nodes → anywhere (image pulls, AWS API calls, external services)
resource "aws_vpc_security_group_egress_rule" "nodes_egress_all" {
  security_group_id = aws_security_group.node_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic from nodes"
}