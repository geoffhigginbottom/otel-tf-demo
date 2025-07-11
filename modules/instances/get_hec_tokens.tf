resource "null_resource" "fetch_hec_tokens" {
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
  depends_on = [null_resource.fetch_hec_tokens]

  program = [
    "${path.module}/read_hec_tokens.sh",
    "${path.module}/hec_tokens.json"
  ]
}

# Outputs
output "hec_metrics_token" {
  value     = data.external.hec_tokens.result["HEC-METRICS"]
  sensitive = true
}

output "hec_otel_token" {
  value     = data.external.hec_tokens.result["OTEL"]
  sensitive = true
}

output "hec_otel_k8s_token" {
  value     = data.external.hec_tokens.result["OTEL-K8S"]
  sensitive = true
}
