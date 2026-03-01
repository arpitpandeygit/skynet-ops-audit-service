project_name     = "skynet-ops-audit-service"
environment      = "staging"
aws_region       = "us-east-1"
alert_email      = "your@email.com"
budget_limit_usd = 20

enable_jwt_auth = false
jwt_audience    = []
jwt_issuer      = ""

api_rate_limit  = 50
api_burst_limit = 100
cors_allowed_origins = ["*"]

log_retention_days          = 7
lambda_reserved_concurrency = 5
lambda_error_threshold      = 5
lambda_duration_threshold   = 3000

enable_deletion_protection = false