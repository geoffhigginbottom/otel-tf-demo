resource "null_resource" "sync_config_files" {
  provisioner "local-exec" {
    command = "aws s3 sync ./config_files/ s3://${var.s3_bucket_name}/config_files/ --delete --exclude '*.tpl' --exclude '*.ignore'"
  }

  triggers = {
    content_hash = md5(join("", concat(
      [for f in fileset("./config_files/", "**") : filemd5("./config_files/${f}")],
      [for f in fileset("./config_files/", "**") : f]  # Include filenames for add/delete detection
    )))
  }
}

resource "null_resource" "sync_scripts" {
  provisioner "local-exec" {
    command = "aws s3 sync ./scripts/ s3://${var.s3_bucket_name}/scripts/ --delete"
  }

  triggers = {
    content_hash = md5(join("", concat(
      [for f in fileset("./scripts/", "**") : filemd5("./scripts/${f}")],
      [for f in fileset("./scripts/", "**") : f]
    )))
  }
}

resource "null_resource" "sync_non_pub_files" {
  provisioner "local-exec" {
    command = "aws s3 sync ./non_public_files/ s3://${var.s3_bucket_name}/non_public_files/ --delete"
  }

  triggers = {
    content_hash = md5(join("", concat(
      [for f in fileset("./non_public_files/", "**") : filemd5("./non_public_files/${f}")],
      [for f in fileset("./non_public_files/", "**") : f]
    )))
  }
}