resource "aws_iam_policy" "s3_access_policy" {
#   name        = "S3AccessPolicy"
  name        = join("-", [var.environment, "S3AccessPolicy"])
  description = "Policy to allow access to S3 bucket"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::eu-west-3-tfdemo-files",
          "arn:aws:s3:::eu-west-3-tfdemo-files/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}
