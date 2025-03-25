resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = join("-", [var.environment, "s3_ec2_instance_profile"])
  role = aws_iam_role.ec2_role.name
}

output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.ec2_instance_profile.name
}