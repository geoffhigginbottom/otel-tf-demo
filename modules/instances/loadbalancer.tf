resource "aws_lb" "gateway-lb" {
  name                       = "${var.environment}-gateway-lb"
  internal                   = true
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.instances_sg.id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = false
  drop_invalid_header_fields = true

  tags = {
    Name = "${var.environment}-gateway-lb"
    splunkit_environment_type = "non-prd"
    splunkit_data_classification = "public"
  }
}

