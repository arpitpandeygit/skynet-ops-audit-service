project_name     = "skynet-ops-audit-service"
environment      = "prod"
aws_region       = "us-east-1"
alert_email      = "your@email.com"
budget_limit_usd = 50

enable_jwt_auth = true

jwt_audience = ["skynet-api"]
jwt_issuer   = "https://skynet-ops-audit-service-prod-auth.auth.us-east-1.amazoncognito.com"

api_rate_limit  = 20
api_burst_limit = 40
cors_allowed_origins = ["https://yourdomain.com"]

log_retention_days          = 14
lambda_reserved_concurrency = 10
lambda_error_threshold      = 3
lambda_duration_threshold   = 2000

enable_deletion_protection = false