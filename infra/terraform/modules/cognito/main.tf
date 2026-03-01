########################################
# Cognito User Pool
########################################

resource "aws_cognito_user_pool" "this" {
  name = "${var.project_name}-${var.environment}-user-pool"

  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

########################################
# User Pool Client
########################################

resource "aws_cognito_user_pool_client" "client" {
  name         = "${var.project_name}-${var.environment}-client"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  allowed_oauth_flows_user_pool_client = true

  allowed_oauth_flows = ["code"]

  allowed_oauth_scopes = [
    "openid",
    "email",
    "profile"
  ]

  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  supported_identity_providers = ["COGNITO"]
}

########################################
# Hosted UI Domain
########################################

resource "aws_cognito_user_pool_domain" "domain" {
  domain       = "${var.project_name}-${var.environment}-auth"
  user_pool_id = aws_cognito_user_pool.this.id
}
