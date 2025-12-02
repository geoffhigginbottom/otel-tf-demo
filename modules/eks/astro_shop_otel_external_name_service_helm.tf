resource "null_resource" "astro_shop_otel_external_name_service_helm_install" {
  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${self.triggers.admin_ip} \
      'helm install otel-externalname-astro-shop ./helm_otel_external_name -n astro-shop'
    EOT
  }

  # provisioner "local-exec" {
  #   when = destroy
  #   command = <<EOT
  #     ssh -o StrictHostKeyChecking=no -i ${self.triggers.private_key_path} ubuntu@${self.triggers.admin_ip} \
  #     'helm delete otel-externalname-astro-shop --namespace astro-shop'
  #   EOT
  # }

  triggers = {
    admin_ip          = var.eks_admin_server_eip
    private_key_path  = var.private_key_path
  }

  depends_on = [
    aws_instance.eks_admin_server,
    aws_eip_association.eks_admin_server_eip_assoc,
    null_resource.astro_shop_helm_install,
  ]
}
