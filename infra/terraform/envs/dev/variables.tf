
variable "project_name" {}
variable "environment" {}
variable "budget_limit_usd" {
  type = number
}
variable "aws_region" {
  type = string
}
variable "alert_email" {
  type = string
}
variable "lambda_error_threshold" {}
variable "lambda_duration_threshold" {}