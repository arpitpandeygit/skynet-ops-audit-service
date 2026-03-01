output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "invoke_arn" {
  value = aws_lambda_function.this.invoke_arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.lambda_logs.name
}