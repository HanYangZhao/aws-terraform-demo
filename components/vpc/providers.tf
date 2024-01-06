terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.3.0"
    }
  }
}


provider "aws" {
  region = "$TF_REGION" # set by envsubst in the template file
  allowed_account_ids  = [var.aws_allowed_account_id]
}

