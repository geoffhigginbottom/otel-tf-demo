resource "aws_eks_cluster" "eks_cluster" {
  name     = var.eks_cluster_name
  # version  = 1.19
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    security_group_ids = [aws_security_group.eks_cluster.id]
    subnet_ids         = var.public_subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster-AmazonEKSVPCResourceController,
  ]
}
