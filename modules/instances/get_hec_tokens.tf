# Only fetch tokens if splunk_ent_count != 0
resource "null_resource" "fetch_hec_tokens" {
  count      = var.splunk_ent_count != 0 ? 1 : 0
  depends_on = [aws_instance.splunk_ent]

  provisioner "local-exec" {
    command = <<EOT
      scp -i ${var.private_key_path} -o StrictHostKeyChecking=no ubuntu@${aws_instance.splunk_ent[0].public_ip}:/tmp/hec_tokens.json ${path.module}/hec_tokens.json
    EOT
  }

  # Add a destroy-time provisioner to delete the file
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/hec_tokens.json"
  }
}

# External data source to read JSON file after it is copied
data "external" "hec_tokens" {
  count      = var.splunk_ent_count != 0 ? 1 : 0
  depends_on = [null_resource.fetch_hec_tokens]

  program = [
    "${path.module}/read_hec_tokens.sh",
    "${path.module}/hec_tokens.json"
  ]
}

# Outputs (conditionally emitted)
output "hec_metrics_token" {
  value     = var.splunk_ent_count != 0 ? data.external.hec_tokens[0].result["HEC-METRICS"] : null
  sensitive = false
}

output "hec_otel_token" {
  value     = var.splunk_ent_count != 0 ? data.external.hec_tokens[0].result["OTEL"] : null
  sensitive = false
}

output "hec_otel_k8s_token" {
  value     = var.splunk_ent_count != 0 ? data.external.hec_tokens[0].result["OTEL-K8S"] : null
  sensitive = false
}
