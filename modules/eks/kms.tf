# Customer-managed KMS key for EKS envelope encryption of Kubernetes Secrets at rest in etcd.
# encryption_config must be set at cluster creation; existing clusters require replacement.

data "aws_iam_policy_document" "eks_secrets_kms" {
  statement {
    sid    = "EnableRootAccountPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowEksService"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowClusterRole"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.eks_cluster.arn]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:DescribeKey",
    ]

    resources = ["*"]
  }
}

resource "aws_kms_key" "eks_secrets" {
  description             = "EKS secrets envelope encryption for ${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.eks_secrets_kms.json

  tags = {
    Name        = join("-", [var.environment, "eks-secrets"])
    Environment = var.environment
    Purpose     = "eks-secrets-envelope-encryption"
  }
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.environment}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}
