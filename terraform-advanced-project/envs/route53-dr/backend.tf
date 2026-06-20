terraform {
  backend "s3" {
    bucket         = "mycompany-tf-state-dev-primary"
    key            = "envs/route53-dr/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock-primary"
    encrypt        = true
  }

  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
