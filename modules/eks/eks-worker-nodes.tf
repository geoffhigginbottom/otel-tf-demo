# resource "aws_eks_node_group" "eks_nodes" {
#   cluster_name    = aws_eks_cluster.eks_cluster.name
#   node_group_name = join("_",[var.environment,"eks_node_group"])
#   node_role_arn   = aws_iam_role.eks_node.arn
#   subnet_ids      = var.public_subnet_ids
#   instance_types  = ["${var.eks_instance_type}"]
#   disk_size       = 100 # testing this new setting - default is 20

#   scaling_config {
#     desired_size = 4
#     max_size     = 6
#     min_size     = 1
#   }
  
#   ami_type = "${var.eks_ami_type}"

#   depends_on = [
#     aws_iam_role_policy_attachment.eks_node-AmazonEKSWorkerNodePolicy,
#     aws_iam_role_policy_attachment.eks_node-AmazonEKS_CNI_Policy,
#     aws_iam_role_policy_attachment.eks_node-AmazonEC2ContainerRegistryReadOnly,
#   ]
# }

# output "aws_eks_node_group_name" {
#   value = aws_eks_node_group.eks_nodes.node_group_name
# }




### Due to new SCPs we need to use Launch Templates for EKS Node Groups so we can add tags and attach a custom SG as we can no longer use
### kubectl patch commands. The custom SG is required to enable the loadbalancer to communicate with the worker nodes for health checks etc.

# -------------------------
# Launch Template for Node Group
# -------------------------
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

# -------------------------
# EKS Node Group
# -------------------------
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.environment}_eks_node_group"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = var.public_subnet_ids

  scaling_config {
    desired_size = 1
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

# -------------------------
# Outputs
# -------------------------
output "aws_eks_node_group_name" {
  value = aws_eks_node_group.eks_nodes.node_group_name
}

output "worker_nodes_sg_id" {
  value = aws_security_group.cluster_worker_nodes_sg.id
}