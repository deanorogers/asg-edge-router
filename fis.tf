
resource "aws_cloudwatch_log_group" "fis_cw_log_group" {
  name = "/aws/fis/events-logs-for_scale-out"
  retention_in_days = 1
}

resource "aws_fis_experiment_template" "ec2_cpu_80" {
  description = "Inject 80% CPU load on all tagged EC2 instances"
  role_arn    = aws_iam_role.lambda_fis_role.arn

#  log_configuration {
#    log_schema_version = 2
#
#    cloudwatch_logs_configuration {
#      log_group_arn = "${aws_cloudwatch_log_group.fis_cw_log_group.arn}:*"
#    }
#  }

  stop_condition {
    source = "none"
  }

  action {
    name      = "cpu-stress"
    action_id = "aws:ssm:send-command"

    parameter {
      key   = "documentArn"
      value = "arn:aws:ssm:us-east-1::document/AWSFIS-Run-CPU-Stress"
    }

    parameter {
      key   = "duration"
      value = "PT5M"
    }

    parameter {
      key   = "documentParameters"
      value = "{\"DurationSeconds\":\"180\", \"CPU\":\"0\", \"LoadPercent\":\"90\"}"
    }

    target {
      key   = "Instances"
      value = "fis-enabled-target"
    }
  }

  target {
    name           = "fis-enabled-target"
    resource_type  = "aws:ec2:instance"
#    resource_type  = "aws:ec2:autoscaling-group"
    selection_mode = "ALL"
#    resource_arns = [
#      aws_autoscaling_group.asg.arn
#    ]
#    count          = 1
#    parameters = {
#      "tag:Name" = "united-edge-router"
#      "count"    = "1"
#    }
    resource_tag {
      key   = "Name"
      value = "united-edge-router"
    }
  }
}

resource "aws_iam_role" "lambda_fis_role" {
  name = "lambda_fis_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "fis.amazonaws.com"
      }
    }]
  })
  tags = {
    Environment = "dev"
    Project     = "ASG"
  }
}

resource "aws_iam_role_policy" "lambda_fis_policy" {
  name   = "lambda_policy"
  role   = aws_iam_role.lambda_fis_role.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:DescribeParameters",
          "ssm:GetParameters",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations",
          "ssm:SendCommand",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
#          "ec2:RebootInstances",
#          "ec2:StopInstances",
#          "ec2:TerminateInstances",
          "fis:StartExperiment",
          "fis:StopExperiment",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "cloudwatch:DescribeAlarms"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
#    ,
#      {
#        Action = [
#          "fis:*"
#        ]
#        Effect   = "Allow"
#        Resource = "*"
#      }
    ]
  }
      )
}