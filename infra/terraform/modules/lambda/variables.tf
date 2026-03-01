variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "ecr_repository_url" {
  type = string
}

variable "lambda_role_arn" {
  type = string
}

variable "dynamodb_table_name" {
  type = string
}

variable "dlq_arn" {
  type = string
}

# ================================
# ENV TUNING (REQUIRED FIX)
# ================================

variable "lambda_reserved_concurrency" {
  type    = number
  default = 5
}

variable "log_retention_days" {
  type    = number
  default = 7
}