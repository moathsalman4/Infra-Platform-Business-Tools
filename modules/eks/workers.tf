resource "aws_iam_role" "workers_role" {
  name = "${var.workers_name}-iam-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      } # meaning only EC2 instances can assume this role
    }]
    Version = "2012-10-17"
  })
}

# lets the node register itself with the EKS cluster and describe cluster info (so kubelet can join)
resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.workers_role.name
}

# lets the VPC CNI plugin assign VPC IPs to pods (manages ENIs, secondary IPs)
resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.workers_role.name
}

# lets nodes pull container images from ECR
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.workers_role.name
}

# lets you connect to nodes via SSM Session Manager (no SSH/keys needed for debugging)
resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.workers_role.name
}

