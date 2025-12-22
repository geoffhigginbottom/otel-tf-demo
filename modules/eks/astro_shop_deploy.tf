
resource "null_resource" "astro_shop_deploy" {
  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${self.triggers.admin_ip} \
      'kubectl apply -f /home/ubuntu/splunk-astronomy-shop.yaml'
    EOT
  }
  
  provisioner "local-exec" {
    when = destroy
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${self.triggers.private_key_path} ubuntu@${self.triggers.admin_ip} \
      'kubectl delete -f /home/ubuntu/splunk-astronomy-shop.yaml'
    EOT
  }

  triggers = {
    admin_ip          = var.eks_admin_server_eip
    private_key_path  = var.private_key_path
  }

  depends_on = [
    aws_instance.eks_admin_server,
    aws_eip_association.eks_admin_server_eip_assoc,
  ]
}