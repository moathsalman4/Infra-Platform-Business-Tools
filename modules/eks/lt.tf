data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2023/x86_64/standard/recommended/image_id"
}

resource "aws_iam_instance_profile" "worker_node" {
  name = "${var.workers_name}-instance-profile"
  role = aws_iam_role.workers_role.name
}

resource "aws_launch_template" "workers" {
  # top-level fields (name_prefix, image_id, instance_type, etc.)
  name_prefix            = "${var.workers_name}-lt-"
  description            = "Launch template for ${var.cluster_name} worker nodes"
  image_id               = data.aws_ssm_parameter.eks_ami.value
  instance_type          = var.instance_types[0] # default instance type for ASG (ASG mixed instances policy will use all types in var.instance_types)
  vpc_security_group_ids = [aws_security_group.node_sg.id]
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.worker_node.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_disk_size_gb
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" #(forces IMDSv2)
    http_put_response_hop_limit = 1          #(the pod-can't-steal-credentials part)
    instance_metadata_tags      = "disabled" # ← ADD THIS LINE EXPLICITLY

  }

  user_data = base64encode(<<-EOT
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: application/node.eks.aws

---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${aws_eks_cluster.main_cluster.name}
    apiServerEndpoint: ${aws_eks_cluster.main_cluster.endpoint}
    certificateAuthority: ${aws_eks_cluster.main_cluster.certificate_authority[0].data}
    cidr: ${aws_eks_cluster.main_cluster.kubernetes_network_config[0].service_ipv4_cidr}

--BOUNDARY--
EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.cluster_name}-worker"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.cluster_name}-worker"
    })
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags

}