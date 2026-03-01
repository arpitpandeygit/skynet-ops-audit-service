provider "aws" {
  region = "us-east-1"
}

# ===============================
# S3 Bucket for Terraform State
# ===============================

resource "aws_s3_bucket" "terraform_state" {
  bucket = "skynet-ops-terraform-state-244143925680"

  tags = {
    Name        = "Terraform State Bucket"
    ManagedBy   = "terraform"
    Project     = "skynet-ops"
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ===============================
# DynamoDB Table for State Lock
# ===============================

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "skynet-ops-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "Terraform State Locks"
    ManagedBy = "terraform"
    Project   = "skynet-ops"
  }
}
