variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "budget_limit_usd" {
  type = number
}

variable "alert_email" {
  type = string
}

# ================= JWT =================

variable "enable_jwt_auth" {
  type    = bool
  default = false
}

variable "jwt_issuer" {
  type    = string
  default = null
}

variable "jwt_audience" {
  type    = list(string)
  default = []
}

# ================= API =================

variable "api_rate_limit" {
  type    = number
  default = 50
}

variable "api_burst_limit" {
  type    = number
  default = 100
}

variable "cors_allowed_origins" {
  type    = list(string)
  default = ["*"]
}

# ================= LOGGING =================

variable "log_retention_days" {
  type    = number
  default = 7
}

# ================= LAMBDA =================

variable "lambda_reserved_concurrency" {
  type    = number
  default = 5
}

# ================= MONITORING =================

variable "lambda_error_threshold" {
  type    = number
  default = 5
}

variable "lambda_duration_threshold" {
  type    = number
  default = 3000
}

# ================= DRIFT PROTECTION =================

variable "enable_deletion_protection" {
  type    = bool
  default = false
}

