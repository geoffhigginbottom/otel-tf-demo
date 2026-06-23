locals {
  config_files_sync = sort([
    for f in fileset("${path.root}/config_files", "**") : f
    if !endswith(f, ".tpl") && !endswith(f, ".ignore")
  ])
  config_files_sync_hash = md5(join("", [
    for f in local.config_files_sync : "${f}${filemd5("${path.root}/config_files/${f}")}"
  ]))

  scripts_sync = sort(fileset("${path.root}/scripts", "**"))
  scripts_sync_hash = md5(join("", [
    for f in local.scripts_sync : "${f}${filemd5("${path.root}/scripts/${f}")}"
  ]))

  # eks/ is rendered and synced by modules/eks/config_render.tf — exclude here to avoid
  # fileset races when local_file updates run during the same apply.
  non_public_sync_files = sort([
    for f in fileset("${path.root}/non_public_files", "**") : f
    if !startswith(f, "eks/")
  ])
  non_public_sync_hash = md5(join("", [
    for f in local.non_public_sync_files : "${f}${filemd5("${path.root}/non_public_files/${f}")}"
  ]))
}

resource "null_resource" "sync_config_files" {
  provisioner "local-exec" {
    command = "aws s3 sync '${path.root}/config_files/' 's3://${var.s3_bucket_name}/config_files/' --delete --exclude '*.tpl' --exclude '*.ignore'"
  }

  triggers = {
    content_hash = local.config_files_sync_hash
  }
}

resource "null_resource" "sync_scripts" {
  provisioner "local-exec" {
    command = "aws s3 sync '${path.root}/scripts/' 's3://${var.s3_bucket_name}/scripts/' --delete"
  }

  triggers = {
    content_hash = local.scripts_sync_hash
  }
}

resource "null_resource" "sync_non_pub_files" {
  provisioner "local-exec" {
    command = "aws s3 sync '${path.root}/non_public_files/' 's3://${var.s3_bucket_name}/non_public_files/' --delete --exclude 'eks/*'"
  }

  triggers = {
    content_hash = local.non_public_sync_hash
  }
}
