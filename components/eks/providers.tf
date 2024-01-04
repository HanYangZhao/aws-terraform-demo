terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.57"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }

  cloud {
    organization = "hanztech"
    workspaces {
      project = "AWS Demo"
      name    = "aws-terraform-demo-eks"
    }
  }
}

provider "aws" {
  region = "ca-central-1" # Default region
  allowed_account_ids  = [var.aws_allowed_account_id]
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2" # Additional region
}