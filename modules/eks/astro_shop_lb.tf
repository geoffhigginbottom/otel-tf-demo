resource "aws_lb" "frontend_proxy_lb" {
  name               = "${var.environment}-frontend-proxy-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.frontend_proxy_sg.id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${var.environment}-frontend-proxy-lb"
    splunkit_environment_type    = "non-prd"
    splunkit_data_classification = "private"
  }
}

# Output the ALB ARN and DNS name
output "frontend_proxy_lb_arn" {
  value = aws_lb.frontend_proxy_lb.arn
}

output "astro_shop_url" {
  value = "http://${aws_lb.frontend_proxy_lb.dns_name}"
}

output "astro_shop_config_url" {
  value = "http://${aws_lb.frontend_proxy_lb.dns_name}/feature"
}