resource "null_resource" "astro_shop_helm_install" {
  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${self.triggers.admin_ip} \
      'helm install astro-shop open-telemetry/opentelemetry-demo --values /home/ubuntu/observability-workshop/workshop/otel-contrib-splunk-demo/opentelemetry-demo-values.yaml'
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${self.triggers.private_key_path} ubuntu@${self.triggers.admin_ip} \
      'helm delete astro-shop --namespace default'
    EOT
  }

  triggers = {
    admin_ip          = var.eks_admin_server_eip
    private_key_path  = var.private_key_path
  }

  depends_on = [
    aws_instance.eks_admin_server,
    aws_eip_association.eks-admin-server-eip-assoc,
  ]
}
