resource "aws_iam_role" "eks_cluster" {
  name = join("-", [var.environment, "cluster"])

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role" "eks_node" {
  name = join("-",[var.environment,"node"])

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}


##### testting #####

# EC2 IAM role for EKS client
resource "aws_iam_role" "eks_client_role" {
  name = "eks-client-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Inline policy giving minimal AWS API access for eksctl/kubectl
resource "aws_iam_policy" "eks_client_full_access" {
  name        = "eks-client-full-access"
  description = "Allows Admin VM to run eksctl/kubectl and query EC2/AutoScaling resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EKS read
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeClusterVersions",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeAddon",
          "eks:ListAddons"
        ]
        Resource = "*"
      },
      # EC2 read
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      },
      # AutoScaling read
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags"
        ]
        Resource = "*"
      },
      # STS
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
      # CloudFormation read
      ,{
        Effect = "Allow"
        Action = [
          "cloudformation:DescribeStacks",
          "cloudformation:ListStacks",
          "cloudformation:ListStackResources"
        ]
        Resource = "*"
      },
      # Register Targets for Load Balancers
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach to the Admin VM role
resource "aws_iam_policy_attachment" "eks_client_full_access_attach" {
  name       = "eks-client-full-access-attach"
  roles      = [aws_iam_role.eks_client_role.name]
  policy_arn = aws_iam_policy.eks_client_full_access.arn
}

# Instance profile to attach the role to EC2
resource "aws_iam_instance_profile" "eks_client_profile" {
  name = "eks-client-profile"
  role = aws_iam_role.eks_client_role.name
}


##### testting #####




resource "aws_iam_role_policy_attachment" "eks_node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_node-AmazonEC2ReadOnlyAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  role       = aws_iam_role.eks_node.name
}