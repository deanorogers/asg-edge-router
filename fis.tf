
resource "aws_cloudwatch_log_group" "fis_cw_log_group" {
  name = "/aws/fis/events-logs-for_scale-out"
  retention_in_days = 1
}

module "ec2_stress_cpu" {
  count = 1

  source = "./ec2_stress_cpu"

  cw_log_arn = aws_cloudwatch_log_group.fis_cw_log_group.arn
  fis_role_arn = aws_iam_role.lambda_fis_role.arn
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
          "cloudwatch:DescribeAlarms"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:fis:${var.region}:${data.aws_caller_identity.current.account_id}:experiment-template/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:aws:ssm:${var.region}::document/AWSFIS-Run-CPU-Stress"
#          "arn:aws:ssm:us-east-1::document/AWS-RunShellScript"
        ]
      },
      {
        Action = [
          "ssm:ListCommands",
          "ssm:ListCommandInvocations"
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
          "*"
#          "${aws_cloudwatch_log_group.fis_cw_log_group.arn}:*"
        ]
      }
    ]
  }
  )
}

#resource "aws_iam_role_policy" "lambda_fis_policy" {
#  name   = "lambda_policy"
#  role   = aws_iam_role.lambda_fis_role.id
#  policy = jsonencode({
#    Version   = "2012-10-17"
#    Statement = [
#      {
#        Action = [
#          "ssm:GetParameter",
#          "ssm:DescribeParameters",
#          "ssm:GetParameters",
#          "ssm:ListCommands",
#          "ssm:ListCommandInvocations",
#          "ssm:SendCommand",
#          "ssm:GetCommandInvocation",
#          "ssm:DescribeInstanceInformation",
#          "ec2:DescribeInstances",
#          "ec2:DescribeInstanceStatus",
##          "ec2:RebootInstances",
##          "ec2:StopInstances",
##          "ec2:TerminateInstances",
##          "fis:StartExperiment",
##          "fis:StopExperiment",
#          "logs:CreateLogGroup",
#          "logs:CreateLogStream",
#          "logs:PutLogEvents",
#          "logs:DescribeLogGroups",
#          "logs:CreateLogDelivery",
#          "logs:DescribeLogStreams",
#          "cloudwatch:DescribeAlarms",
#          "ssm:GetDocument",
#          "ssm:DescribeDocument"
#        ]
#        Effect   = "Allow"
#        Resource = [
#          "arn:aws:fis:${var.region}:${data.aws_caller_identity.current.account_id}:experiment-template/*",
#          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*",
#          "arn:aws:ssm:${var.region}::document/AWSFIS-Run-CPU-Stress",
#          "arn:aws:ssm:us-east-1::document/AWS-RunShellScript"
#        ]
#      },
#      {
#        "Effect": "Allow",
#        "Action": [
#          "ssm:ListCommands"
#        ]
#        Resource = [
#          "arn:aws:ssm:${var.region}::document/*"
#        ]
#      },
#      {
#        "Effect": "Allow",
#        "Action": [
#          "logs:CreateLogGroup",
#          "logs:CreateLogStream",
#          "logs:PutLogEvents",
#          "logs:DescribeLogStreams",
#          "logs:DescribeLogGroups",
#          "logs:CreateLogDelivery"
#        ],
#        "Resource": [
##          "${aws_cloudwatch_log_group.fis_cw_log_group.arn}:*",
#          "*"
#        ]
#      }
#
##    ,
##      {
##        Action = [
##          "fis:*"
##        ]
##        Effect   = "Allow"
##        Resource = "*"
##      }
#    ]
#  }
#      )
#}