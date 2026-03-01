variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "enable_deletion_protection" {
  type    = bool
  default = false
}

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