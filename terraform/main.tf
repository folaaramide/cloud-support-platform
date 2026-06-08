terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "incident_bucket" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_sns_topic" "incident_alerts" {
  name = "incident-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.incident_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_iam_role" "lambda_role" {
  name = "cloud-support-lambda-role"

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
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "incident_handler" {
  filename         = "../lambda/lambda.zip"
  function_name    = "incident-handler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("../lambda/lambda.zip")
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.incident_handler.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_apigatewayv2_api" "incident_api" {
  name          = "incident-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]

    allow_methods = [
      "POST",
      "OPTIONS"
    ]

    allow_headers = [
      "content-type"
    ]
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.incident_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.incident_handler.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "incident_route" {
  api_id    = aws_apigatewayv2_api.incident_api.id
  route_key = "POST /incident"

  target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.incident_api.id
  name        = "prod"
  auto_deploy = true
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "lambda-s3-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"


    Statement = [{
      Action = [
        "s3:PutObject"
      ]

      Effect = "Allow"

      Resource = "${aws_s3_bucket.incident_bucket.arn}/*"
    }]

  })
}

resource "aws_iam_role_policy" "lambda_sns_policy" {
  name = "lambda-sns-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "sns:Publish"
      ]

      Resource = aws_sns_topic.incident_alerts.arn
    }]

  })
}
