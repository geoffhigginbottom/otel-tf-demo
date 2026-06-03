check "eks_node_group_scaling_bounds" {
  assert {
    condition     = var.eks_node_group_min_size <= var.eks_node_group_desired_size && var.eks_node_group_desired_size <= var.eks_node_group_max_size
    error_message = "EKS node group scaling must satisfy min_size <= desired_size <= max_size."
  }
}
