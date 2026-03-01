data "aws_caller_identity" "current" {}

module "ecr" {
  source        = "./modules/ecr"
  project_name  = var.project_name
  environment   = var.environment
}

module "dynamodb" {
  source        = "./modules/dynamodb"
  project_name  = var.project_name
  environment   = var.environment

  enable_deletion_protection = var.enable_deletion_protection
}

module "iam" {
  source             = "./modules/iam"
  project_name       = var.project_name
  environment        = var.environment
  dynamodb_table_arn = module.dynamodb.table_arn
  dlq_arn = module.dlq.dlq_arn
}

module "lambda" {
  source                         = "./modules/lambda"
  project_name                   = var.project_name
  environment                    = var.environment
  ecr_repository_url             = module.ecr.repository_url
  lambda_role_arn                = module.iam.lambda_role_arn
  dynamodb_table_name            = module.dynamodb.table_name
  dlq_arn                        = module.dlq.dlq_arn

  lambda_reserved_concurrency    = var.lambda_reserved_concurrency
  log_retention_days             = var.log_retention_days
}

module "apigateway" {
  source               = "./modules/apigateway"
  project_name         = var.project_name
  environment          = var.environment
  lambda_invoke_arn    = module.lambda.invoke_arn
  lambda_function_name = module.lambda.function_name

  enable_jwt_auth      = var.enable_jwt_auth
  jwt_issuer   = var.enable_jwt_auth ? module.cognito[0].issuer_url : null
  jwt_audience = var.enable_jwt_auth ? [module.cognito[0].client_id] : []

  api_rate_limit       = var.api_rate_limit
  api_burst_limit      = var.api_burst_limit
log_retention_days = var.log_retention_days
  cors_allowed_origins = var.cors_allowed_origins
}

module "monitoring" {
  source = "./modules/monitoring"

  lambda_name               = module.lambda.function_name
  lambda_log_group          = module.lambda.log_group_name
  project_name              = var.project_name
  environment               = var.environment
  alarm_topic_arn           = module.alerts.topic_arn

  lambda_error_threshold    = var.lambda_error_threshold
  lambda_duration_threshold = var.lambda_duration_threshold
}

module "budget" {
  source          = "./modules/budget"
  project_name    = var.project_name
  environment     = var.environment
  budget_limit_usd    = var.budget_limit_usd
}

module "alerts" {
  source        = "./modules/alerts"
  project_name  = var.project_name
  environment   = var.environment
  alert_email   = var.alert_email
}

module "dlq" {
  source        = "./modules/dlq"
  project_name  = var.project_name
  environment   = var.environment
}

module "cognito" {
  source       = "./modules/cognito"
  project_name = var.project_name
  environment  = var.environment

  callback_urls = ["https://example.com/callback"]
  logout_urls   = ["https://example.com/logout"]

  count = var.enable_jwt_auth ? 1 : 0
}

module "cicd" {
  source       = "./modules/cicd"
  project_name = var.project_name
  environment  = var.environment
  account_id   = data.aws_caller_identity.current.account_id
  github_repo  = "arpitpandeygit/skynet-ops-audit-service"
}