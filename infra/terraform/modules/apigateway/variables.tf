variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "lambda_invoke_arn" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

# ===== JWT =====

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

# ===== API THROTTLING =====

variable "api_rate_limit" {
  type    = number
  default = 50
}

variable "api_burst_limit" {
  type    = number
  default = 100
}

# ===== CORS =====

variable "cors_allowed_origins" {
  type    = list(string)
  default = ["*"]
}

variable "log_retention_days" {
  type    = number
  default = 7
}