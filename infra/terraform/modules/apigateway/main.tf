############################################
# HTTP API (Cost Optimized)
############################################

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.project_name}-${var.environment}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.cors_allowed_origins
    allow_methods = ["GET", "POST"]
    allow_headers = ["Authorization", "Content-Type"]
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
    
}

############################################
# JWT AUTHORIZER (OPTIONAL)
############################################

resource "aws_apigatewayv2_authorizer" "jwt" {
  count = var.enable_jwt_auth ? 1 : 0

  api_id          = aws_apigatewayv2_api.this.id
  authorizer_type = "JWT"
  name            = "jwt-authorizer"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = var.jwt_audience
    issuer   = var.jwt_issuer
  }
}

############################################
# LAMBDA INTEGRATION
############################################

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

############################################
# ROUTE
############################################

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "$default"

  authorization_type = var.enable_jwt_auth ? "JWT" : "NONE"
  authorizer_id      = var.enable_jwt_auth ? aws_apigatewayv2_authorizer.jwt[0].id : null

  target = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

############################################
# ACCESS LOG GROUP
############################################

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

############################################
# STAGE (Auto Deploy + Throttling + Logs)
############################################

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId = "$context.requestId"
      status    = "$context.status"
      routeKey  = "$context.routeKey"
      ip        = "$context.identity.sourceIp"
      latency   = "$context.responseLatency"
      error     = "$context.error.message"
    })
  }

  default_route_settings {
    detailed_metrics_enabled = true

    throttling_burst_limit = var.api_burst_limit
    throttling_rate_limit  = var.api_rate_limit
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

############################################
# LAMBDA PERMISSION
############################################

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}