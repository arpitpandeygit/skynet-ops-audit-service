# Lambda Errors Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-lambda-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = var.lambda_error_threshold
  alarm_description   = "Lambda error rate high"
  treat_missing_data  = "notBreaching"
  alarm_actions = [var.alarm_topic_arn]

  dimensions = {
    FunctionName = var.lambda_name
  }
}

# Lambda Duration Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.project_name}-${var.environment}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = var.lambda_duration_threshold
  alarm_description   = "Lambda latency high (>2s avg)"
  treat_missing_data  = "notBreaching"
  alarm_actions = [var.alarm_topic_arn]

  dimensions = {
    FunctionName = var.lambda_name
  }
}

# Lambda Throttles Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.project_name}-${var.environment}-lambda-throttles"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda throttling detected"
  treat_missing_data  = "notBreaching"
  alarm_actions = [var.alarm_topic_arn]

  dimensions = {
    FunctionName = var.lambda_name
  }
}

resource "aws_cloudwatch_log_metric_filter" "error_filter" {
  name           = "${var.project_name}-${var.environment}-error-filter"
  log_group_name = var.lambda_log_group
  pattern        = "{ $.level = 50 }"

  metric_transformation {
    name      = "ApplicationErrors"
    namespace = "Custom/Lambda"
    value     = "1"
  }
}