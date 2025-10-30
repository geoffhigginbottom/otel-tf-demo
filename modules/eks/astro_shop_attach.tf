resource "null_resource" "astro_shop_attach_nodes" {
  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${self.triggers.admin_ip} \
      '/home/ubuntu/astro_shop_attach_nodes.sh ${var.eks_cluster_name} ${aws_eks_node_group.demo.node_group_name} ${aws_lb_target_group.frontend_proxy_tg.arn} "30080" ${var.region}'
    EOT
  }

#   provisioner "local-exec" {
#     when = destroy
#     command = <<EOT
#       ssh -o StrictHostKeyChecking=no -i ${self.triggers.private_key_path} ubuntu@${self.triggers.admin_ip} \
#       'xxx'
#     EOT
#   }


  triggers = {
    admin_ip          = var.eks_admin_server_eip
    private_key_path  = var.private_key_path
  }

  depends_on = [
    aws_instance.eks_admin_server,
    aws_eip_association.eks-admin-server-eip-assoc,
    null_resource.astro_shop_helm_install,
  ]
}
