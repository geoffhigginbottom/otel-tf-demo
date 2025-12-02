
resource "null_resource" "aws_cli_config" {
  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${self.triggers.admin_ip} \
      /tmp/generate_aws_config.sh '${var.aws_access_key_id}' '${var.aws_secret_access_key}' '${var.aws_session_token}' '${var.region}'
    EOT
  }

  triggers = {
    admin_ip   = aws_instance.eks_admin_server.public_ip
    aws_access_key_id = var.aws_access_key_id
    aws_secret_key    = var.aws_secret_access_key
    aws_session_token = var.aws_session_token

    always_run = timestamp()  # forces rerun every apply
  }

  depends_on = [
    aws_instance.eks_admin_server,
    aws_eip_association.eks_admin_server_eip_assoc,
  ]
}
