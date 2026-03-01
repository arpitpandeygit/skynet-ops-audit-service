variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "callback_urls" {
  type    = list(string)
  default = []
}

variable "logout_urls" {
  type    = list(string)
  default = []
}
