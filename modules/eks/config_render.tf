# Templates live in config_files/eks/; rendered YAML (tokens) goes to non_public_files/eks/ then S3.
locals {
  eks_templates_dir = "${path.root}/config_files/eks"
  eks_rendered_dir  = "${path.root}/non_public_files/eks"
}

resource "local_file" "eks_secrets" {
  content = templatefile("${local.eks_templates_dir}/secrets.yaml.tpl", {
    hec_otel_k8s_token = var.hec_otel_k8s_token
    splunk_private_ip  = var.splunk_private_ip
    eks_access_token   = var.eks_access_token
    rum_token          = var.rum_access_token
    hec_token          = var.hec_otel_k8s_token
    hec_url            = "https://${var.splunk_private_ip}:8088/services/collector/event"
    aws_lb_dns_name    = aws_lb.frontend_proxy_lb.dns_name
    environment        = var.environment
  })
  filename = "${local.eks_rendered_dir}/secrets.yaml"
}

resource "local_file" "eks_otel_collector_values" {
  content = templatefile("${local.eks_templates_dir}/splunk-otel-collector-values.yaml.tpl", {
    gateway_enabled          = var.eks_otel_gateway_enabled
    gateway_replica_count    = var.eks_otel_gateway_replica_count
    gateway_cpu_request      = var.eks_otel_gateway_cpu_request
    gateway_memory_request   = var.eks_otel_gateway_memory_request
    gateway_cpu_limit        = var.eks_otel_gateway_cpu_limit
    gateway_memory_limit     = var.eks_otel_gateway_memory_limit
    splunk_platform_enabled  = var.splunk_ent_count == 1 && var.instances_enabled
  })
  filename = "${local.eks_rendered_dir}/splunk-otel-collector-values.yaml"
}

resource "local_file" "eks_astronomy_shop_collector_values" {
  content = templatefile("${local.eks_templates_dir}/splunk-astronomy-shop-collector-values.yaml.tpl", {
    eks_access_token = var.eks_access_token
    realm            = var.realm
    gateway_enabled  = var.eks_otel_gateway_enabled
  })
  filename = "${local.eks_rendered_dir}/splunk-astronomy-shop-collector-values.yaml"
}

resource "null_resource" "sync_eks_non_public_config_to_s3" {
  provisioner "local-exec" {
    command = "aws s3 sync '${local.eks_rendered_dir}/' 's3://${var.s3_bucket_name}/non_public_files/eks/' --delete"
  }

  triggers = {
    content_hash = md5(join("", [
      local_file.eks_secrets.content,
      local_file.eks_otel_collector_values.content,
      local_file.eks_astronomy_shop_collector_values.content,
    ]))
  }

  depends_on = [
    local_file.eks_secrets,
    local_file.eks_otel_collector_values,
    local_file.eks_astronomy_shop_collector_values,
  ]
}
