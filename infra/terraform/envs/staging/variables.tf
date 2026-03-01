variable "project_name" {}
variable "environment" {}
variable "aws_region" {}
variable "alert_email" {}
variable "budget_limit_usd" {}

variable "enable_jwt_auth" {}
variable "jwt_issuer" {}
variable "jwt_audience" {
  type = list(string)
}

variable "api_rate_limit" {}
variable "api_burst_limit" {}
variable "cors_allowed_origins" {
  type = list(string)
}
variable "lambda_error_threshold" {}
variable "lambda_duration_threshold" {}