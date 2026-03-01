variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "lambda_name" {
  type = string
}

variable "alarm_topic_arn" {
  type = string
}

variable "lambda_log_group" {
  type = string
}

# ================================
# ENVIRONMENT TUNING
# ================================

variable "lambda_error_threshold" {
  type = number
}

variable "lambda_duration_threshold" {
  type = number
}