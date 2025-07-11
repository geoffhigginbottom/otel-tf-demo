resource "null_resource" "patch_frontend_proxy_apply" {
  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${self.triggers.admin_ip} \
      "kubectl patch svc frontend-proxy -n default -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'"
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${self.triggers.private_key_path} ubuntu@${self.triggers.admin_ip} \
      "kubectl patch svc frontend-proxy -n default -p '{\"spec\": {\"type\": \"ClusterIP\"}}'"
    EOT
  }

  triggers = {
    admin_ip          = var.eks_admin_server_eip
    private_key_path  = var.private_key_path
  }

  depends_on = [
    aws_instance.eks_admin_server,
    aws_eip_association.eks-admin-server-eip-assoc,
    null_resource.astro_shop_helm_install
  ]
}
