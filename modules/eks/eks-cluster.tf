resource "aws_eks_cluster" "eks_cluster" {
  name = var.eks_cluster_name
  # version  = 1.19
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = var.eks_fargate_enabled ? true : false
    endpoint_public_access  = true
    subnet_ids = var.eks_fargate_enabled ? concat(
      var.public_subnet_ids,
      var.private_subnet_ids
    ) : var.public_subnet_ids
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
    resources = ["secrets"]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster-AmazonEKSVPCResourceController,
    aws_iam_role_policy.eks_cluster_kms,
    aws_kms_key.eks_secrets,
  ]
}
