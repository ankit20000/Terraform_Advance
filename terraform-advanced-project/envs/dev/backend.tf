terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "terrafrom-backedn-class-dev-ankit"
    key            = "envs/dev/terraform.tfstate"
    region         = "ap-south-1"
    # dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }

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
