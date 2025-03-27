resource "null_resource" "sync_config_files" {
  provisioner "local-exec" {
    command = "aws s3 sync ./config_files/ s3://${var.s3_bucket_name}/config_files/ --delete"
  }

  triggers = {
    folder_hash = md5(join("", [for f in fileset("./config_files/", "**") : filesha1("./config_files/${f}")]))
  }
}

resource "null_resource" "sync_scripts" {
  provisioner "local-exec" {
    command = "aws s3 sync ./scripts/ s3://${var.s3_bucket_name}/scripts/ --delete"
  }

  triggers = {
    folder_hash = md5(join("", [for f in fileset("./scripts/", "**") : filesha1("./scripts/${f}")]))
  }
}

resource "null_resource" "sync_non_pub_files" {
  provisioner "local-exec" {
    command = "aws s3 sync ./non_public_files/ s3://${var.s3_bucket_name}/non_public_files/ --delete"
  }

  triggers = {
    folder_hash = md5(join("", [for f in fileset("./non_public_files/", "**") : filesha1("./non_public_files/${f}")]))
  }
}