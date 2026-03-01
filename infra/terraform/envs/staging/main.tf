module "skynet_ops" {
  source          = "../../"
  project_name    = "skynet-ops-audit-service"
  environment     = "staging"
  aws_region      = "us-east-1"
  budget_limit_usd = 20
  alert_email     = "your@email.com"
}
