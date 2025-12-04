# Map Admin VM IAM role into aws-auth
resource "null_resource" "map_admin_vm_role" {
  provisioner "local-exec" {
    command = <<EOT
set -e

# Define retry parameters
ATTEMPTS=0
MAX_ATTEMPTS=20 # Increased attempts to account for longer EKS initialization
SLEEP_TIME=15   # Increased sleep time for better stability

# Define the path for the aws-auth.yaml file in the current working directory
AWS_AUTH_FILE="${path.cwd}/aws-auth.yaml"

echo "Attempting to update kubeconfig for EKS cluster: ${aws_eks_cluster.eks_cluster.name}..."
until aws eks update-kubeconfig --name ${aws_eks_cluster.eks_cluster.name} --region ${var.region} || [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; do
    ATTEMPTS=$((ATTEMPTS+1))
    echo "Kubeconfig update failed. Retrying in $SLEEP_TIME seconds... (Attempt $ATTEMPTS/$MAX_ATTEMPTS)"
    sleep $SLEEP_TIME
done
if [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; then
    echo "Failed to update kubeconfig after $MAX_ATTEMPTS attempts. Exiting."
    exit 1
fi
echo "Kubeconfig updated successfully."

# Reset attempts for the next set of commands
ATTEMPTS=0
echo "Attempting to fetch and update aws-auth ConfigMap..."
until kubectl get configmap aws-auth -n kube-system -o yaml > "$AWS_AUTH_FILE" && \
      sed -i '' '/mapRoles: |/a \
    - rolearn: ${aws_iam_role.eks_client_role.arn}\
      username: ec2-admin\
      groups:\
        - system:masters' "$AWS_AUTH_FILE" && \
      kubectl apply -f "$AWS_AUTH_FILE" || [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; do
    ATTEMPTS=$((ATTEMPTS+1))
    echo "aws-auth ConfigMap update failed. Retrying in $SLEEP_TIME seconds... (Attempt $ATTEMPTS/$MAX_ATTEMPTS)"
    sleep $SLEEP_TIME
done
if [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; then
    echo "Failed to update aws-auth ConfigMap after $MAX_ATTEMPTS attempts. Exiting."
    exit 1
fi
echo "aws-auth ConfigMap updated successfully."
EOT
  }

  # Provisioner to delete the aws-auth.yaml file during terraform destroy
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.cwd}/aws-auth.yaml"
    # To ensure the destroy provisioner runs, even if the create provisioner failed,
    # you might consider adding on_failure = continue, but it's often not needed for simple cleanup.
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_iam_role.eks_client_role
  ]
}