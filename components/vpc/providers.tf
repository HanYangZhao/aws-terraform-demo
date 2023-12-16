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
  region = "ca-central-1"  # Default region
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"  # Additional region
}