variable "project_name" {}
variable "environment" {}
variable "aws_region" {}
variable "alert_email" {}
variable "budget_limit_usd" {}

variable "enable_jwt_auth" {
  type = bool
}



variable "api_rate_limit" {
  type = number
}

variable "api_burst_limit" {
  type = number
}

variable "cors_allowed_origins" {
  type = list(string)
}
variable "lambda_error_threshold" {}
variable "lambda_duration_threshold" {}