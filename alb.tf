resource "aws_lb" "nginx-alb" {
  name                       = "nginx-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.router-alb-sg.id]
  enable_deletion_protection = false
  subnets                    = [aws_subnet.subnet1.id, aws_subnet.subnet2.id, aws_subnet.subnet3.id]

  tags = local.common_tags
}

resource "aws_lb_listener" "nginx-listener" {

  load_balancer_arn = aws_lb.nginx-alb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = "{\"greeting\":\"Not today!\"}"
      status_code  = "200"
    }
  }
}

resource "aws_alb_listener_rule" "salutation" {

  listener_arn = aws_lb_listener.nginx-listener.arn

  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.edge_tg.arn
        weight = 100
      }
      stickiness {
        enabled  = false
        duration = 1
      }
    }
  }

  lifecycle {
    ignore_changes = [
      action
    ]
  }

  condition {
    path_pattern {
      values = ["/salutation"]
    }
  }
}

resource "aws_lb_target_group" "edge_tg" {
  name        = "nginx-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"

  health_check {
    path                = "/salutation"
    protocol            = "HTTP"
    port                = "traffic-port"  # Uses the same port as the target group
    interval            = 30              # Health check interval in seconds
    timeout             = 5               # Time before marking as failed
    healthy_threshold   = 3               # Number of successful checks before healthy
    unhealthy_threshold = 3               # Number of failed checks before unhealthy
    matcher             = "200-299"       # Expected HTTP response code range
  }

  vpc_id = aws_vpc.main.id

}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.asg.name
  lb_target_group_arn    = aws_lb_target_group.edge_tg.arn
}