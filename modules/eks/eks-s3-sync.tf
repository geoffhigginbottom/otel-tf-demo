# Ensures static config_files/ (including eks/) are in S3 before the admin server first pull.
resource "null_resource" "wait_for_s3_config_sync" {
  triggers = {
    s3_config_files_sync_id = var.s3_config_files_sync_id
  }
}
