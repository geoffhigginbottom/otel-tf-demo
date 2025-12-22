resource "aws_launch_template" "eks_nodes" {
  name_prefix   = "${var.environment}-eks-"
  instance_type = var.eks_instance_type

  network_interfaces {
    security_groups             = [aws_security_group.cluster_worker_nodes_sg.id]
    associate_public_ip_address = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 100  # Disk size in GB
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Added this block to configure instance metadata options
  metadata_options {
    http_tokens                 = "required"              # Enforce IMDSv2 for security
    http_endpoint               = "enabled"               # Ensure IMDS endpoint is enabled
    http_put_response_hop_limit = 2                       # Set hop limit to 2 for pods to access IMDS
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                          = "${var.environment}-eks-node"
      Environment                   = var.environment
      splunkit_environment_type     = "non-prd"
      splunkit_data_classification  = "private"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name                          = "${var.environment}-eks-node-volume"
      Environment                   = var.environment
      splunkit_environment_type     = "non-prd"
      splunkit_data_classification  = "private"
    }
  }
}

resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.environment}_eks_node_group"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = var.public_subnet_ids

  scaling_config {
    desired_size = 3
    max_size     = 6
    min_size     = 1
  }

  ami_type = var.eks_ami_type

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

output "aws_eks_node_group_name" {
  value = aws_eks_node_group.eks_nodes.node_group_name
}

output "worker_nodes_sg_id" {
  value = aws_security_group.cluster_worker_nodes_sg.id
}