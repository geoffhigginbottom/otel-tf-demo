locals {
  safe_hec_token = var.hec_otel_k8s_token != null ? var.hec_otel_k8s_token : ""
  
  configmap_and_secrets = templatefile("${path.module}/configmap-and-secrets.yaml.tmpl", {
    realm                = var.realm
    fqdn                 = var.fqdn
    index                = var.eks_splunk_index
    cluster_name         = var.eks_cluster_name
    environment          = var.environment
    access_token         = var.access_token
    hec_token            = local.safe_hec_token
  })

  astro_shop_values = templatefile("${path.module}/config_files/astro_shop_values.yaml.tpl", {
    environment = var.environment
  })
}
