terraform {
  backend "s3" {
    bucket         = "mycompany-tf-state-dev-secondary"
    key            = "envs/dev-secondary/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-state-lock-secondary"
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
  region = var.aws_region
}
