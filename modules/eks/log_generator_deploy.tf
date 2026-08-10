resource "null_resource" "log_generator_deploy" {
  provisioner "local-exec" {
    command = <<EOT
      ${var.eks_fargate_enabled ? "${path.module}/scripts/wait_for_fargate_profiles.sh ${var.eks_cluster_name} ${var.region} ${var.eks_cluster_name}-coredns ${var.eks_cluster_name}-default ${var.eks_cluster_name}-kube-system" : "true"}
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${self.triggers.admin_ip} \
      'kubectl apply -f /home/ubuntu/log-generator.yaml'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i ${self.triggers.private_key_path} ubuntu@${self.triggers.admin_ip} \
      'kubectl delete -f /home/ubuntu/log-generator.yaml --ignore-not-found --wait=false' || true
    EOT
  }

  triggers = {
    admin_ip         = var.eks_admin_server_eip
    private_key_path = var.private_key_path
    manifest_hash    = filemd5("${path.root}/config_files/eks/log-generator.yaml")
  }

  depends_on = [
    aws_instance.eks_admin_server,
    aws_eip_association.eks_admin_server_eip_assoc,
    null_resource.map_admin_vm_role,
  ]
}
