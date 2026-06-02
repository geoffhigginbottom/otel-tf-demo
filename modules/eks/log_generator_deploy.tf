resource "null_resource" "log_generator_deploy" {
  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${self.triggers.admin_ip} \
      'kubectl apply -f /home/ubuntu/log-generator.yaml'
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${self.triggers.private_key_path} ubuntu@${self.triggers.admin_ip} \
      'kubectl delete -f /home/ubuntu/log-generator.yaml --ignore-not-found'
    EOT
  }

  triggers = {
    admin_ip         = var.eks_admin_server_eip
    private_key_path = var.private_key_path
    manifest_hash    = filemd5("${path.module}/config_files/log-generator.yaml")
  }

  depends_on = [
    aws_instance.eks_admin_server,
    aws_eip_association.eks_admin_server_eip_assoc,
  ]
}
