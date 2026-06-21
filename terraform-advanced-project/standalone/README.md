# Standalone Terraform Demo

This directory contains a self-contained Terraform configuration that can be run directly with no external module dependencies.

## What it creates
- AWS VPC
- public subnet
- Internet gateway
- public route table
- security group for SSH/HTTP
- EC2 instance running Amazon Linux 2 with a simple web page

## How to run

Set your AWS credentials and desired region, then run:

```bash
cd terraform-advanced-project/standalone
terraform init
terraform plan
terraform apply
```

If your AWS region is not `ap-south-1`, override it with:

```bash
export AWS_REGION=ap-south-1
export TF_VAR_aws_region=ap-south-1
```

## Notes

- This example uses a local Terraform state file (`terraform.tfstate`) in the `standalone` folder.
- It does not depend on any external modules.
- SSH is allowed from anywhere (`0.0.0.0/0`) for demo purposes only.
- The AMI is looked up dynamically in the target AWS region.
- If you want `terraform apply` to use a specific SSH CIDR, set `TF_VAR_ssh_cidr` before applying.
