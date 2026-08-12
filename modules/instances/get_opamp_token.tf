resource "null_resource" "configure_opamp" {
  count = var.splunk_ent_count != 0 ? 1 : 0

  depends_on = [aws_instance.splunk_ent, null_resource.splunk_cert_gen]

  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${var.splunk_ent_eip} \
        'sudo chmod +x /tmp/configure_splunk_opamp.sh && sudo /tmp/configure_splunk_opamp.sh "${var.splunk_admin_pwd}"'
    EOT
  }
}

resource "null_resource" "fetch_opamp_token" {
  count = var.splunk_ent_count != 0 ? 1 : 0

  depends_on = [null_resource.configure_opamp]

  provisioner "local-exec" {
    command = <<EOT
      scp -i ${var.private_key_path} -o StrictHostKeyChecking=no ubuntu@${var.splunk_ent_eip}:/tmp/opamp_token.json ${path.module}/opamp_token.json
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/opamp_token.json"
  }
}

data "external" "opamp_token" {
  count      = var.splunk_ent_count != 0 ? 1 : 0
  depends_on = [null_resource.fetch_opamp_token]

  program = [
    "${path.module}/read_hec_tokens.sh",
    "${path.module}/opamp_token.json"
  ]
}

output "splunk_opamp_token" {
  value     = var.splunk_ent_count != 0 ? data.external.opamp_token[0].result["token"] : null
  sensitive = true
}
