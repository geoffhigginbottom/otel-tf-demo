resource "null_resource" "splunk_cert" {
  count = var.splunk_ent_count != 0 ? 1 : 0
  
  depends_on = [aws_instance.splunk_ent, null_resource.splunk_cert_gen]

  provisioner "local-exec" {
    command = <<EOT
      scp -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${var.splunk_ent_eip}:/tmp/mySplunkWebCert.pem ./mySplunkWebCert.pem
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ./mySplunkWebCert.pem"
  }
}

# # Conditionally read file only if splunk_ent_count != 0
# data "local_file" "mySplunkWebCert" {
#   count     = var.splunk_ent_count != 0 ? 1 : 0
#   filename  = "./mySplunkWebCert.pem"
#   depends_on = [null_resource.splunk_cert_gen]
# }