output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.ec2_instance_profile.name
}

output "s3_access_policy_arn" {
  value = aws_iam_policy.s3_access_policy.arn
}

output "config_files_sync_id" {
  description = "Changes when config_files/ (including config_files/eks/) have been synced to S3."
  value       = null_resource.sync_config_files.id
}
