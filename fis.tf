
resource "aws_cloudwatch_log_group" "fis_cw_log_group" {
  name = "/aws/fis/events-logs-for_scale-out"
  retention_in_days = 1
}

resource "aws_fis_experiment_template" "ec2_cpu_80" {

  description = "Inject 80% CPU load on all tagged EC2 instances"
  role_arn    = aws_iam_role.lambda_fis_role.arn

  log_configuration {
    log_schema_version = 2

    cloudwatch_logs_configuration {
      log_group_arn = "${aws_cloudwatch_log_group.fis_cw_log_group.arn}:*"
    }
  }

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

  tags = merge(local.common_tags, {Name = "ec2_cpu_load"})
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

resource "aws_cloudwatch_log_resource_policy" "fis_log_delivery_policy" {
  policy_name = "FISLogDeliveryPolicy"

  policy_document = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowFISDeliveryLogs",
        Effect    = "Allow",
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        },
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.fis_cw_log_group.name}:*",
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
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
          "logs:CreateLogDelivery",
          "logs:DescribeLogStreams",
          "cloudwatch:DescribeAlarms"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogDelivery"
        ],
        "Resource": [
          "${aws_cloudwatch_log_group.fis_cw_log_group.arn}:*"
        ]
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