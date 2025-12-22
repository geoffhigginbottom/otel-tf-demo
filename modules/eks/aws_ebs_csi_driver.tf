data "aws_caller_identity" "current" {}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = var.eks_cluster_name
  addon_name   = "aws-ebs-csi-driver"

  service_account_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ebs-csi-irsa-role"

  # resolve_conflicts_on_create = "OVERWRITE"
  # resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_cluster.eks_cluster
  ]
}
