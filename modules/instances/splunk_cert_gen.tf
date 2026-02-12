# resource "null_resource" "splunk_cert_gen" {
#   count = var.splunk_ent_count != 0 ? 1 : 0
  
#   depends_on = [aws_instance.splunk_ent, aws_eip_association.eip_assoc]


#   provisioner "local-exec" {
#     command = <<EOT
#       ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${var.splunk_ent_eip} \
#       'sudo /tmp/certs.sh ${var.slo_certpath} ${var.passphrase} ${var.fqdn} ${var.country} ${var.state} ${var.location} ${var.org} ${var.le_certpath}'
#     EOT
#   }
# }


resource "null_resource" "splunk_cert_gen" {
  count = var.splunk_ent_count != 0 ? 1 : 0
  
  depends_on = [aws_instance.splunk_ent, aws_eip_association.eip_assoc]

  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${var.splunk_ent_eip} \
      'echo "sudo /tmp/certs.sh ${var.slo_certpath} ${var.passphrase} ${var.fqdn} ${var.country} ${var.state} ${var.location} ${var.org} ${var.le_certpath}" > /tmp/certs_gen_cmd.txt; \
       sudo /tmp/certs.sh "${var.slo_certpath}" "${var.passphrase}" "${var.fqdn}" "${var.country}" "${var.state}" "${var.location}" "${var.org}" "${var.le_certpath}"'
    EOT
  }
}