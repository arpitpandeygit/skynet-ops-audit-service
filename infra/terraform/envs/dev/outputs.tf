output "api_endpoint" {
  value = module.skynet_ops.api_endpoint
}

output "lambda_function_name" {
  value = module.skynet_ops.lambda_function_name
}

output "dynamodb_table_name" {
  value = module.skynet_ops.dynamodb_table_name
}

output "ecr_repository_url" {
  value = module.skynet_ops.ecr_repository_url
}
