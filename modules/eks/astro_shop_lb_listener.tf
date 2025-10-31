resource "aws_lb_listener" "frontend_proxy_listener" {
  load_balancer_arn = aws_lb.frontend_proxy_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_proxy_tg.arn
  }
}
