output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.ec2_instance_profile.name
}

output "s3_access_policy_arn" {
  value = aws_iam_policy.s3_access_policy.arn
}
