locals {
  fargate_subnet_ids = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : var.public_subnet_ids

  # Use static map keys (subnet index) because subnet IDs from module outputs are unknown at plan time.
  cluster_subnet_tags = var.eks_fargate_enabled ? merge(
    { for i in range(length(var.public_subnet_ids)) : "public-${i}" => var.public_subnet_ids[i] },
    { for i in range(length(var.private_subnet_ids)) : "private-${i}" => var.private_subnet_ids[i] }
    ) : {
    for i in range(length(var.public_subnet_ids)) : "public-${i}" => var.public_subnet_ids[i]
  }

  public_subnet_elb_tags = var.eks_fargate_enabled ? {
    for i in range(length(var.public_subnet_ids)) : "public-${i}" => var.public_subnet_ids[i]
  } : {}

  private_subnet_internal_elb_tags = var.eks_fargate_enabled ? {
    for i in range(length(var.private_subnet_ids)) : "private-${i}" => var.private_subnet_ids[i]
  } : {}
}

resource "aws_iam_role" "eks_fargate_pod_execution" {
  count = var.eks_fargate_enabled ? 1 : 0
  name  = join("-", [var.environment, "eks-fargate-pod-execution"])

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_fargate_pod_execution" {
  count      = var.eks_fargate_enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.eks_fargate_pod_execution[0].name
}

# EKS creates a self-referencing ingress rule on the cluster security group automatically
# ("Allows EFA traffic…" / all traffic from the same SG). Do not add a duplicate here.

resource "aws_eks_fargate_profile" "coredns" {
  count = var.eks_fargate_enabled ? 1 : 0

  cluster_name           = aws_eks_cluster.eks_cluster.name
  fargate_profile_name   = "${var.eks_cluster_name}-coredns"
  pod_execution_role_arn = aws_iam_role.eks_fargate_pod_execution[0].arn
  subnet_ids             = local.fargate_subnet_ids

  selector {
    namespace = "kube-system"
    labels = {
      k8s-app = "kube-dns"
    }
  }

  depends_on = [aws_eks_cluster.eks_cluster]
}

resource "aws_eks_fargate_profile" "default" {
  count = var.eks_fargate_enabled ? 1 : 0

  cluster_name           = aws_eks_cluster.eks_cluster.name
  fargate_profile_name   = "${var.eks_cluster_name}-default"
  pod_execution_role_arn = aws_iam_role.eks_fargate_pod_execution[0].arn
  subnet_ids             = local.fargate_subnet_ids

  selector {
    namespace = "default"
  }

  depends_on = [aws_eks_cluster.eks_cluster]
}

resource "aws_eks_fargate_profile" "kube_system" {
  count = var.eks_fargate_enabled ? 1 : 0

  cluster_name           = aws_eks_cluster.eks_cluster.name
  fargate_profile_name   = "${var.eks_cluster_name}-kube-system"
  pod_execution_role_arn = aws_iam_role.eks_fargate_pod_execution[0].arn
  subnet_ids             = local.fargate_subnet_ids

  selector {
    namespace = "kube-system"
  }

  depends_on = [aws_eks_cluster.eks_cluster]
}

resource "aws_ec2_tag" "cluster_subnet_shared" {
  for_each = local.cluster_subnet_tags

  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.eks_cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "public_subnet_elb" {
  for_each = local.public_subnet_elb_tags

  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_subnet_internal_elb" {
  for_each = local.private_subnet_internal_elb_tags

  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}
