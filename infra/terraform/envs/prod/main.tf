module "skynet_ops" {
  source          = "../../"

  # Core Identity
  project_name    = "skynet-ops-audit-service"
  environment     = "prod"
  aws_region      = "us-east-1"

  # Budget & Alerts
  budget_limit_usd = 50
  alert_email      = "arpitxid@gmail.com"

  # ===============================
  # 🔐 SECURITY (PROD STRICT)
  # ===============================
  enable_jwt_auth = true
  jwt_audience    = ["skynet-api"]
  jwt_issuer      = "https://<YOUR-COGNITO-DOMAIN>.auth.us-east-1.amazoncognito.com"

  # ===============================
  # 🚦 API Protection
  # ===============================
  api_rate_limit  = 20
  api_burst_limit = 40
  cors_allowed_origins = ["https://yourdomain.com"]

  # ===============================
  # 🧠 ENVIRONMENT TUNING
  # ===============================
  log_retention_days          = 14
  lambda_reserved_concurrency = 10
  lambda_error_threshold      = 3
  lambda_duration_threshold   = 2000

  # ===============================
  # 🔒 DRIFT PROTECTION
  # ===============================
  enable_deletion_protection = true
}