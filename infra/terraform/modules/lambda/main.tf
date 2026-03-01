resource "aws_lambda_function" "this" {
  function_name = "${var.project_name}-${var.environment}"
  role          = var.lambda_role_arn
  package_type  = "Image"

  image_uri = "${var.ecr_repository_url}:latest"

  memory_size = 512
  timeout     = 10

  reserved_concurrent_executions = var.lambda_reserved_concurrency

  environment {
    variables = {
      APP_ENV              = var.environment
      STORE_BACKEND        = "dynamodb"
      DYNAMODB_TABLE       = var.dynamodb_table_name
      LOG_LEVEL            = "info"
      SERVICE_NAME         = var.project_name
      METRICS_DEMO_ENABLED = "true"
    }
  }

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = var.dlq_arn
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
  }

    
}

resource "aws_lambda_function_event_invoke_config" "async_config" {
  function_name = aws_lambda_function.this.function_name

  maximum_retry_attempts       = 2
  maximum_event_age_in_seconds = 60

  destination_config {
    on_failure {
      destination = var.dlq_arn
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}