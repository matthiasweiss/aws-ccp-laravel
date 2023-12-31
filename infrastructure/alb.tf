resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.default_vpc.id
}

resource "aws_lb" "alb" {
  name = "${var.application_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_az_a.id, aws_subnet.public_subnet_az_b.id]

  access_logs {
    bucket  = aws_s3_bucket.alb_access_logs.bucket
    enabled = true
  }
}

output "alb_url" {
  value = "https://${aws_lb.alb.dns_name}"
}

resource "aws_security_group_rule" "alb_allow_outbound" {
  security_group_id = aws_security_group.alb_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_allow_ingress_http" {
  security_group_id = aws_security_group.alb_sg.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_security_group_rule" "alb_allow_ingress_https" {
  security_group_id = aws_security_group.alb_sg.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

variable "ALB_CERTIFICATE_ARN" {
  type = string
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  certificate_arn   = var.ALB_CERTIFICATE_ARN

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "No associated service found"
      status_code  = 404
    }
  }
}

resource "aws_lb_listener_rule" "https_listener_rule" {
  listener_arn = aws_lb_listener.https_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_lb_target_group" "alb_target_group" {
  name = "${var.application_name}-alb-target-group"
  depends_on  = [aws_lb.alb]
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.default_vpc.id
  target_type = "ip"

  health_check {
    timeout  = 15
    interval = 20
    path     = "/"
    protocol = "HTTP"
    matcher  = "200-404"
  }
}
