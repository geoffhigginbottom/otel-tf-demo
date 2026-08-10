resource "null_resource" "astro_shop_fargate_setup" {
  count = var.eks_fargate_enabled ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i ${var.private_key_path} ubuntu@${self.triggers.admin_ip} \
      '/home/ubuntu/patch_fargate_workloads.sh default splunk-otel-collector /home/ubuntu/fargate-overrides.yaml && \
       /home/ubuntu/astro_shop_attach_fargate.sh ${aws_lb_target_group.frontend_proxy_tg.arn} 8080 default opentelemetry.io/name=frontend-proxy'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i ${self.triggers.private_key_path} ubuntu@${self.triggers.admin_ip} \
      'kubectl delete deployment sql-server-fraud -n default --ignore-not-found --wait=false' || true
    EOT
  }

  triggers = {
    admin_ip         = var.eks_admin_server_eip
    private_key_path = var.private_key_path
    manifest_hash    = filemd5("${path.root}/config_files/eks/splunk-astronomy-shop.yaml")
    overrides_hash   = filemd5("${path.root}/config_files/eks/fargate-overrides.yaml")
    patch_script_hash = filemd5("${path.module}/scripts/patch_fargate_workloads.sh")
    target_group_arn = aws_lb_target_group.frontend_proxy_tg.arn
  }

  depends_on = [
    aws_instance.eks_admin_server,
    aws_eip_association.eks_admin_server_eip_assoc,
    null_resource.astro_shop_deploy,
    aws_eks_fargate_profile.default[0],
  ]
}
