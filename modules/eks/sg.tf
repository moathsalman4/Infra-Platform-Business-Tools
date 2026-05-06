resource "aws_security_group" "cluster_sg" {
  name        = "${var.cluster_name}-sg"
  description = "EKS cluster control plane security group"
  vpc_id      = var.vpc_id

  # No inline ingress/egress rules — defined as separate resources below
  # (avoids the "rules drift" problem with inline rules)

  tags = {
    Name = "${var.cluster_name}-sg"
  }
}

# INGRESS: nodes → control plane API
resource "aws_vpc_security_group_ingress_rule" "cluster_ingress_from_nodes" {
  security_group_id            = aws_security_group.cluster_sg.id
  referenced_security_group_id = aws_security_group.node_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Allow worker nodes to call the Kubernetes API"
}

# EGRESS: control plane → anywhere
resource "aws_vpc_security_group_egress_rule" "cluster_egress_all" {
  security_group_id = aws_security_group.cluster_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic from control plane"
}

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

# INGRESS: control plane → kubelet (kubectl logs/exec, metrics-server)
resource "aws_vpc_security_group_ingress_rule" "nodes_from_cluster_kubelet" {
  security_group_id            = aws_security_group.node_sg.id
  referenced_security_group_id = aws_security_group.cluster_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  description                  = "Allow control plane to reach kubelet on nodes"
}

# INGRESS: control plane → nodes on 443 (extension API servers, admission webhooks)
resource "aws_vpc_security_group_ingress_rule" "nodes_from_cluster_https" {
  security_group_id            = aws_security_group.node_sg.id
  referenced_security_group_id = aws_security_group.cluster_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Allow control plane HTTPS to nodes (webhooks, extension APIs)"
}

# EGRESS: nodes → anywhere (image pulls, AWS API calls, external services)
resource "aws_vpc_security_group_egress_rule" "nodes_egress_all" {
  security_group_id = aws_security_group.node_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic from nodes"
}