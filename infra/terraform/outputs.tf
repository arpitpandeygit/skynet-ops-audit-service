output "api_endpoint" {
  value = module.apigateway.api_endpoint
}

output "lambda_function_name" {
  value = module.lambda.function_name
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}