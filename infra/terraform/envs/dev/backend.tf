terraform {
  backend "s3" {
    bucket         = "skynet-ops-terraform-state-244143925680"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "skynet-ops-terraform-locks"
    encrypt        = true
  }
}