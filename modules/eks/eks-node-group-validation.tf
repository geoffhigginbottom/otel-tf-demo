check "eks_node_group_scaling_bounds" {
  assert {
    condition = var.eks_fargate_enabled || (
      var.eks_node_group_min_size <= var.eks_node_group_desired_size &&
      var.eks_node_group_desired_size <= var.eks_node_group_max_size
    )
    error_message = "EKS node group scaling must satisfy min_size <= desired_size <= max_size."
  }
}

check "fargate_requires_private_subnets" {
  assert {
    condition     = !var.eks_fargate_enabled || length(var.private_subnet_ids) > 0
    error_message = "eks_fargate_enabled requires private_subnet_ids (NAT gateway must also be enabled on the VPC)."
  }
}
