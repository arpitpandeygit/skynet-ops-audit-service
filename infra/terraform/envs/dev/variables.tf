variable "project_name" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "alert_email" { type = string }
variable "budget_limit_usd" { type = number }

variable "api_rate_limit" { type = number }
variable "api_burst_limit" { type = number }
variable "cors_allowed_origins" { type = list(string) }

variable "lambda_error_threshold" { type = number }
variable "lambda_duration_threshold" { type = number }

variable "log_retention_days" { type = number }
variable "lambda_reserved_concurrency" { type = number }

variable "enable_jwt_auth" { type = bool }
variable "jwt_issuer" { type = string }
variable "jwt_audience" { type = list(string) }

variable "enable_deletion_protection" { type = bool }