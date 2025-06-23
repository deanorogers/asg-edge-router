resource "aws_iam_role" "lambda_role" {
  name = "lambda_asg_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Environment = "dev"
    Project     = "ASG"
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "autoscaling:PutLifecycleHook",
          "autoscaling:StartInstanceRefresh",
          "autoscaling:CompleteLifecycleAction",
          "autoscaling:CancelInstanceRefresh",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DeleteLifecycleHook",
          "autoscaling:UpdateAutoScalingGroup",
          "glue:*",
          "ec2:ModifyLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "acm-pca:*",
          "acm:*",
          "fis:*"
        ]
        Effect   = "Allow"
        Resource = "*"
        #        Resource = "arn:aws:elasticloadbalancing:eu-west-1:107404535822:truststore/**"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

#############################################################
# Function for ASG refresh
# Has 3 actions:
## commence
## continue (if smoke test OK)
## rollback
#############################################################

data "archive_file" "zip_index" {
  type        = "zip"
  source_file = "lambda_functions/custom_asg_refresh/src/main.py" # Path to your index.py file
  output_path = "lambda_function.zip"                             # Path for the zip output
}

resource "aws_lambda_function" "asg_refresh_lambda" {
  function_name = "asg_refresh_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.handler"
  runtime       = "python3.8"

  # Inline Python code
  #source_code_hash = filebase64sha256("lambda_function.zip")
  source_code_hash = data.archive_file.zip_index.output_base64sha256
  filename         = data.archive_file.zip_index.output_path

  environment {
    variables = {
      ASG_NAME             = aws_autoscaling_group.asg.name
      MIN_HEALTHY_PERCENT  = 80
      INSTANCE_WARM_UP_SEC = 30
    }
  }

  tags = {
    Environment = "dev"
    Project     = "alb_access_log"
  }
  depends_on = [data.archive_file.zip_index]
}

#############################################################
# Function for Crawler start
#############################################################

data "archive_file" "glue_crawler_zip_index" {
  type        = "zip"
  source_file = "lambda_functions/glue_crawler_start/src/main.py" # Path to your index.py file
  output_path = "lambda_function_crawler.zip"                     # Path for the zip output
}

resource "aws_lambda_function" "glue_crawler_lambda" {
  function_name = "glue_crawler_start_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.handler"
  runtime       = "python3.8"
  timeout       = 20

  # Inline Python code
  #source_code_hash = filebase64sha256("lambda_function.zip")
  source_code_hash = data.archive_file.glue_crawler_zip_index.output_base64sha256
  filename         = data.archive_file.glue_crawler_zip_index.output_path

  environment {
    variables = {
      CRAWLER_NAME = aws_glue_crawler.athena_alb_partitioned_crawler.name
    }
  }

  tags = {
    Environment = "dev"
    Project     = "glue_crawler"
  }
  depends_on = [data.archive_file.glue_crawler_zip_index]
}


#############################################################
# Function for LT clone
#############################################################

data "archive_file" "launch_template_zip_index" {
  type        = "zip"
  source_file = "lambda_functions/clone_launch_template/src/main.py" # Path to your index.py file
  output_path = "lambda_function_clone_launch_template.zip"                     # Path for the zip output
}

resource "aws_lambda_function" "launch_template_lambda" {
  function_name = "launch_template_start_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.handler"
  runtime       = "python3.8"
  timeout       = 20

  # Inline Python code
  #source_code_hash = filebase64sha256("lambda_function.zip")
  source_code_hash = data.archive_file.launch_template_zip_index.output_base64sha256
  filename         = data.archive_file.launch_template_zip_index.output_path

  tags = {
    Environment = "dev"
    Project     = "launch_template"
  }
  depends_on = [data.archive_file.launch_template_zip_index]
}

#############################################################
# Function for certificate request via ACM and PCA
#############################################################

data "archive_file" "create_secret_object_zip_index" {
  type        = "zip"
  source_file = "lambda_functions/create_secret_object/src/main.py" # Path to your index.py file
  output_path = "lambda_function_create_secret_object.zip"                     # Path for the zip output
}

resource "aws_lambda_function" "create_secret_object" {
  function_name = "create_secret_object_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.handler"
  runtime       = "python3.8"
  timeout       = 20

  # Inline Python code
  #source_code_hash = filebase64sha256("lambda_function.zip")
  source_code_hash = data.archive_file.create_secret_object_zip_index.output_base64sha256
  filename         = data.archive_file.create_secret_object_zip_index.output_path

  tags = {
    Environment = "dev"
    Project     = "create_secret_object"
  }
  depends_on = [data.archive_file.create_secret_object_zip_index]
}

#############################################################
# Function for adding multiple accounts to FIS experiment
#############################################################

data "archive_file" "multi_account_fis_zip_index" {
  type        = "zip"
  source_file = "lambda_functions/enable_multi_account_fis/src/main.py" # Path to your index.py file
  output_path = "lambda_function_enable_multi_account_fis.zip"                     # Path for the zip output
}

resource "aws_lambda_function" "multi_account_fis_zip_index" {
  function_name = "multi_account_fis_zip_index"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.handler"
  runtime       = "python3.8"
  timeout       = 20

  # Inline Python code
  #source_code_hash = filebase64sha256("lambda_function.zip")
  source_code_hash = data.archive_file.multi_account_fis_zip_index.output_base64sha256
  filename         = data.archive_file.multi_account_fis_zip_index.output_path

  tags = {
    Environment = "dev"
    Project     = "enable_multi_account_fis"
  }
  depends_on = [data.archive_file.multi_account_fis_zip_index]
}
