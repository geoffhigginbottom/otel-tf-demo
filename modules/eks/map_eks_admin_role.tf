# Map Admin VM IAM role into aws-auth
resource "null_resource" "map_admin_vm_role" {
  provisioner "local-exec" {
    command = <<EOT
set -e
aws eks update-kubeconfig --name ${aws_eks_cluster.eks_cluster.name} --region ${var.region}

# Fetch current aws-auth
kubectl get configmap aws-auth -n kube-system -o yaml > /tmp/aws-auth.yaml

# Append Admin VM role under mapRoles (2 spaces indentation)
sed -i '' '/mapRoles: |/a \
    - rolearn: ${aws_iam_role.eks_client_role.arn}\
      username: ec2-admin\
      groups:\
        - system:masters' /tmp/aws-auth.yaml

# Apply updated config
kubectl apply -f /tmp/aws-auth.yaml
EOT
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_iam_role.eks_client_role
  ]
}

