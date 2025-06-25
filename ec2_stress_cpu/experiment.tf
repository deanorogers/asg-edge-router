resource "aws_fis_experiment_template" "ec2_cpu_80" {

  description = "Inject 80% CPU load on all tagged EC2 instances"
  role_arn    = var.fis_role_arn

  log_configuration {
    log_schema_version = 2

    cloudwatch_logs_configuration {
      log_group_arn = "${var.cw_log_arn}:*"
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
      value = "PT1M"
    }

    parameter {
      key   = "documentParameters"
      value = "{\"DurationSeconds\":\"60\", \"CPU\":\"0\", \"LoadPercent\":\"20\"}"
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

  experiment_options {
    account_targeting = "single-account"
  }

  tags = merge(local.common_tags, {Name = "ec2_cpu_load"})
}