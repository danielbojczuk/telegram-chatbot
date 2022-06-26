data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

variable "s3_deployment_bucket" {
  type = string
}

variable "secrets_manager_id" {
  type = string
}