# Helm install/upgrade for Splunk OTel Collector — idempotent and re-runs when values or mode change.
# (Admin server remote-exec only runs on instance create; this null_resource covers toggles and config fixes.)

locals {
  helm_release_name = "splunk-otel-collector"

  helm_upgrade_prefix = join(" ", [
    "helm upgrade --install ${local.helm_release_name}",
    "--namespace default",
    "--create-namespace",
    "--set cloudProvider='aws'",
    "--set distribution='${local.helm_distribution}'",
    "--set fullnameOverride='${local.helm_release_name}'",
    "--set splunkObservability.accessToken='${var.eks_access_token}'",
    "--set clusterName='${var.eks_cluster_name}'",
    "--set splunkObservability.realm='${var.realm}'",
    local.helm_gateway_set_flags,
    "--set splunkObservability.profilingEnabled='true'",
    "--set splunkObservability.infrastructureMonitoringEventsEnabled=true",
    "--set splunkObservability.secureAppEnabled=true",
    "--set environment='${var.environment}'",
  ])

  helm_upgrade_enterprise_suffix = join(" ", [
    "--set splunkPlatform.endpoint='${local.splunk_hec_endpoint}'",
    "--set splunkPlatform.insecureSkipVerify=true",
    "--set splunkPlatform.token='${var.hec_otel_k8s_token}'",
    "--set splunkPlatform.index='${var.eks_splunk_index}'",
    "--set splunkPlatform.logsEnabled=true",
  ])

  helm_upgrade_chart_suffix = join(" ", [
    "splunk-otel-collector-chart/splunk-otel-collector",
    "-f splunk-otel-collector-values.yaml",
    "-f splunk-astronomy-shop-collector-values.yaml",
  ])

  helm_upgrade_command = join(" ", [
    local.helm_upgrade_prefix,
    local.use_enterprise ? local.helm_upgrade_enterprise_suffix : "",
    local.helm_upgrade_chart_suffix,
  ])
}

resource "null_resource" "otel_collector_deploy" {
  provisioner "local-exec" {
    command = <<EOT
      ${var.eks_fargate_enabled ? "${path.module}/scripts/wait_for_fargate_profiles.sh ${var.eks_cluster_name} ${var.region} ${var.eks_cluster_name}-coredns ${var.eks_cluster_name}-default ${var.eks_cluster_name}-kube-system" : "true"}
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${self.triggers.admin_ip} \
      'set -euo pipefail; \
       /home/ubuntu/eks-s3-sync.sh pull; \
       helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart 2>/dev/null || true; \
       helm repo update; \
       ${local.helm_upgrade_command}'
    EOT
  }

  triggers = {
    admin_ip          = var.eks_admin_server_eip
    private_key_path  = var.private_key_path
    helm_config_hash  = md5(local.helm_upgrade_command)
    values_hash       = md5(join("", [local_file.eks_otel_collector_values.content, local_file.eks_astronomy_shop_collector_values.content]))
    fargate_enabled   = tostring(var.eks_fargate_enabled)
    gateway_enabled   = tostring(var.eks_fargate_enabled || var.eks_otel_gateway_enabled)
  }

  depends_on = [
    aws_instance.eks_admin_server,
    aws_eip_association.eks_admin_server_eip_assoc,
    null_resource.sync_eks_non_public_config_to_s3,
    aws_eks_node_group.eks_nodes,
  ]
}
