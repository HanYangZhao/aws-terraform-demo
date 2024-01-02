terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.3.0"
    }
  }

  cloud {
    organization = "hanztech"
    workspaces {
      project = "AWS Demo"
      name    = "aws-terraform-demo-vpc"
    }
  }
}


provider "aws" {
  region = "ca-central-1" # Default region
  allowed_account_ids  = var.aws_allowed_account_ids
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2" # Additional region
}