resource "aws_iam_role" "ec2_sqs_role" {
  name = join("-", [var.environment, "ec2_sqs_access_role"])

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_sqs_access_policy" {
  name        = join("-", [var.environment, "SQSAccessPolicy"])
  description = "Policy to allow access to SQS queue from EC2 instance"
  
  policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:GetQueueUrl",
        "sqs:ListQueues"
      ],
    #   "Resource": "arn:aws:sqs:${var.region}:${var.account_id}:${var.queue_name}"
      "Resource": "*"
    }
  ]
})
}

resource "aws_iam_role_policy_attachment" "attach_sqs_policy" {
  role       = aws_iam_role.ec2_sqs_role.name
  policy_arn = aws_iam_policy.ec2_sqs_access_policy.arn
}

resource "aws_iam_instance_profile" "ec2_sqs_instance_profile" {
  name = join("-", [var.environment, "sqs_ec2_instance_profile"])
  role = aws_iam_role.ec2_sqs_role.name
}