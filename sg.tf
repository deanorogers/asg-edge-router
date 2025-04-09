# SECURITY GROUPS #

######################
# router service ALB
# allow traffic from my local IP
######################
resource "aws_security_group" "router-alb-sg" {
  name   = "router-alb-sg"
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}

## add to EC2 instance using Console
resource "aws_security_group_rule" "router-alb-sg-rule-ingress" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = aws_security_group.router-alb-sg.id
  cidr_blocks       = [var.local_ip] # my public IP
}

resource "aws_security_group_rule" "router-alb-sg-rule-egress" {
  type              = "egress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = aws_security_group.router-alb-sg.id
  cidr_blocks       = [aws_vpc.main.cidr_block] # of EC2 instances
}
