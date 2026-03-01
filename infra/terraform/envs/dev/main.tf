module "skynet_ops" {
  source            = "../../"
  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  alert_email       = var.alert_email
  budget_limit_usd  = var.budget_limit_usd
  enable_jwt_auth = false
api_rate_limit  = 50
api_burst_limit = 100
cors_allowed_origins = ["*"]
}