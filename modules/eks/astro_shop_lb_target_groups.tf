resource "aws_lb_target_group" "frontend_proxy_tg" {
  name        = "${var.environment}-frontend-proxy-tg"
  port        = var.eks_fargate_enabled ? 8080 : 30080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = var.eks_fargate_enabled ? "ip" : "instance"

  health_check {
    protocol            = "HTTP"
    path                = "/"
    port                = var.eks_fargate_enabled ? "8080" : "30080"
    matcher             = "200-399"
    interval            = 10
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.environment}-frontend-proxy-tg"
  }
}

output "aws_lb_target_group_arn" {
  value = aws_lb_target_group.frontend_proxy_tg.arn
}