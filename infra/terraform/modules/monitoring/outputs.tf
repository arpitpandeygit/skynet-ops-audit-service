output "lambda_error_alarm_name" {
  value = aws_cloudwatch_metric_alarm.lambda_errors.alarm_name
}