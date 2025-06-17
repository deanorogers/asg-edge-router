data "aws_vpc" "main" {
  id = aws_vpc.main.id
}

resource "aws_security_group" "nginx_security_group" {
  name        = "asg-security-group"
  description = "ASG Security Group"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.router-alb-sg.id]
  }

  # direct to allow smoke testing test
  ingress {
    description = "HTTP from Client for smoke testing"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.local_ip]
  }

  # needed by yum
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "keypair" {
  key_name   = "my_ec2_key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILFfU4ioN0rnqa+HoNfUsSFTDhfe9vPEJLe4vCdfnsT4 deanrogers@Deans-MacBook-Pro.local"
}

## Launch Template and Security Group
resource "aws_launch_template" "launch_template" {
  name          = "aws_launch_template"
  image_id      = "ami-02f624c08a83ca16f" ## Amazon linux 2
  instance_type = "t2.micro"

  monitoring {
    enabled = true
  }

  network_interfaces {
    device_index    = 0
    security_groups = [aws_security_group.nginx_security_group.id]
  }
  #  user_data = base64encode("${local.user_data}")
  user_data = base64encode(templatefile("${path.module}/userdata.tpl", {
    count = 6
  }))

  key_name = "my_ec2_key"

  iam_instance_profile {
    name = "ec2_instance_profile"
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "united-edge-router"
    }
  }

  tags = {
    Name = "asg-ec2-template"
  }
}

resource "aws_autoscaling_group" "asg" {
  name             = "nginx_asg"
  max_size         = 3
  min_size         = 1
  desired_capacity = 2
#  max_size         = 0
#  min_size         = 0
#  desired_capacity = 0
  #  vpc_zone_identifier = [aws_subnet.subnet1.id, aws_subnet.subnet2.id, aws_subnet.subnet3.id]
  vpc_zone_identifier = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

#  mixed_instances_policy {
#    launch_template {
#      launch_template_specification {
#        launch_template_name = aws_launch_template.launch_template.name
#        version = "$Latest"
#      }
#
#      override {
#        instance_type     = "t2.micro"
#        weighted_capacity = "100"
#      }
#
#      override {
#        instance_type     = "t2.small"
#        weighted_capacity = "100"
#      }
#    }
#
#  }

  launch_template {
    name    = aws_launch_template.launch_template.name
    version = "$Latest"
  }
}

resource "aws_iam_role" "ec2_assume_role" {
  name = "ec2_assume_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_ec2_assume_ssm_policy" {
  role       = aws_iam_role.ec2_assume_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_assume_role.name
}

resource "aws_cloudwatch_metric_alarm" "scale_out_alarm" {
  alarm_name          = "scale-out-alarm-at-70"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 30
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Alarm to scale out when CPU exceeds 70%"
  alarm_actions       = [aws_autoscaling_policy.scale_out_policy.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

resource "aws_autoscaling_policy" "scale_out_policy" {
  name = "scale-out-policy"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

## reduce
#resource "aws_cloudwatch_metric_alarm" "scale_in_alarm" {
#  alarm_name          = "scale-in-alarm-at-30"
#  comparison_operator = "LessThanThreshold"
#  evaluation_periods  = 3
#  metric_name         = "CPUUtilization"
#  namespace           = "AWS/AutoScaling"
#  period              = 300
#  statistic           = "Average"
#  threshold           = 30
#  alarm_description   = "Alarm to scale in when CPU drops below 30%"
#  alarm_actions       = [aws_autoscaling_policy.scale_in_policy.arn]
#}
#
#resource "aws_autoscaling_policy" "scale_in_policy" {
#  name                   = "scale-in-policy"
#  scaling_adjustment     = -1
#  adjustment_type        = "ChangeInCapacity"
#  autoscaling_group_name = aws_autoscaling_group.asg.name
#}
