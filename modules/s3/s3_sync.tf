resource "null_resource" "sync_config_files" {
  provisioner "local-exec" {
    command = "aws s3 sync ./config_files/ s3://${var.s3_bucket_name}/config_files/ --delete"
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "sync_scripts" {
  provisioner "local-exec" {
    command = "aws s3 sync ./scripts/ s3://${var.s3_bucket_name}/scripts/ --delete"
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "sync_non_pub_files" {
  provisioner "local-exec" {
    command = "aws s3 sync ./non_public_files/ s3://${var.s3_bucket_name}/non_public_files/ --delete"
  }

  triggers = {
    always_run = timestamp()
  }
}
