resource "aws_dynamodb_table" "this" {
  name         = "${var.project_name}-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
deletion_protection_enabled = var.enable_deletion_protection
  hash_key = "eventId"

  attribute {
    name = "eventId"
    type = "S"
  }

  attribute {
    name = "tenantId"
    type = "S"
  }

  attribute {
    name = "storedAt"
    type = "S"
  }

  global_secondary_index {
    name               = "tenantId-index"
    hash_key           = "tenantId"
    range_key          = "storedAt"
    projection_type    = "ALL"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }

   
}