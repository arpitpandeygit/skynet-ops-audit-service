project_name     = "skynet-ops-audit-service"
environment      = "dev"
aws_region       = "us-east-1"
alert_email      = "arpitxid@gmail.com"
budget_limit_usd = 50

# API
enable_jwt_auth = false
jwt_audience    = []
jwt_issuer      = ""

api_rate_limit  = 100
api_burst_limit = 200
cors_allowed_origins = ["*"]

# ENV tuning
log_retention_days          = 3
lambda_reserved_concurrency = 2
lambda_error_threshold      = 10
lambda_duration_threshold   = 5000

enable_deletion_protection = false