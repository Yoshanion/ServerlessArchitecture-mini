resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name           = "BasicTable"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "BasicDynamoDBTable"
  }
}

# Lambda
resource "aws_lambda_function" "basic_lambda" {
  function_name = "BasicLambdaFunction"

  s3_bucket = "my-test-bucket"
  s3_key    = "lambda_functions.zip"

  handler = "lambda_function.lambda_handler"
  runtime = "python3.8"
  role    = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.basic-dynamodb-table.name
    }
  }
  reserved_concurrent_executions = 10
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
}

# resource "aws_iam_policy" "lambda_minimal_policy" {
#   name        = "lambda_minimal_policy"
#   description = "A policy that grants minimal permissions to a lambda function."
#   policy      = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           "dynamodb:GetItem",
#           "dynamodb:PutItem",
#           "dynamodb:UpdateItem",
#           "dynamodb:DeleteItem"
#         ]
#         Effect   = "Allow"
#         Resource = aws_dynamodb_table.basic_dynamodb_table.arn
#       },
#     ]
#   })
# }

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.basic_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.basic_api.execution_arn}/*/*/data"
}

# AWS API Geteway 

resource "aws_api_gateway_rest_api" "basic_api" {
  name        = "BasicApi"
  description = "API for handling requests to DynamoDB"
}

resource "aws_api_gateway_resource" "api_resource" {
  rest_api_id = aws_api_gateway_rest_api.basic_api.id
  parent_id   = aws_api_gateway_rest_api.basic_api.root_resource_id
  path_part   = "data"
}

resource "aws_api_gateway_method" "api_method" {
  rest_api_id   = aws_api_gateway_rest_api.basic_api.id
  resource_id   = aws_api_gateway_resource.api_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.basic_api.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.basic_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.basic_api.id
  stage_name  = "prod"
}

output "api_endpoint" {
  value       = "${aws_api_gateway_deployment.api_deployment.invoke_url}/data"
  sensitive   = true
  description = "endpoint"
}


resource "aws_api_gateway_api_key" "api_key" {
  name = "MyApiKey"
}

resource "aws_api_gateway_usage_plan" "api_usage_plan" {
  name = "MyUsagePlan"

  api_stages {
    api_id = aws_api_gateway_rest_api.basic_api.id
    stage  = aws_api_gateway_deployment.api_deployment.stage_name
  }

  quota_settings {
    limit  = 1000
    period = "MONTH"
  }

  throttle_settings {
    burst_limit = 20
    rate_limit  = 10
  }
}

resource "aws_api_gateway_usage_plan_key" "api_key_usage_plan" {
  key_id        = aws_api_gateway_api_key.api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.api_usage_plan.id
}

# CloudWatch Alarms

resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name                = "high_error_rate"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "Errors"
  namespace                 = "AWS/Lambda"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "This metric monitors lambda errors"
  insufficient_data_actions = []

  dimensions = {
    FunctionName = aws_lambda_function.basic_lambda.function_name
  }
}