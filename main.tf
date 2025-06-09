provider "aws" {
  region = "eu-north-1"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "eks-delete-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "eks-delete-policy"
  role   = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "eks:DeleteCluster",
          "eks:DescribeCluster"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/delete_eks.py"
  output_path = "${path.module}/lambda/delete_eks.zip"
}

resource "aws_lambda_function" "eks_delete" {
  function_name = "eks-cluster-auto-delete"
  role          = aws_iam_role.lambda_exec_role.arn
  runtime       = "python3.11"
  handler       = "delete_eks.lambda_handler"
  filename      = data.archive_file.lambda_zip.output_path
  timeout       = 60

  environment {
    variables = {
      CLUSTER_NAME = var.cluster_name
    }
  }
}

resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "daily-eks-delete-trigger"
  schedule_expression = "cron(0 22 * * ? *)" # 10 PM UTC daily
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "eksDeleteTarget"
  arn       = aws_lambda_function.eks_delete.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.eks_delete.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

