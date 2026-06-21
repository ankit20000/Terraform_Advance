# Advanced Terraform Real-Time Project (Reference Repo)

Enterprise-style Terraform layout matching the interview topics:
state/backends, modularization, IAM security, Ansible integration,
GitHub Actions OIDC CI/CD, and a production VPC + EC2 + ALB + ASG stack.

## Structure

```
terraform-advanced-project/
├── modules/
│   ├── backend-bootstrap/   # one-time: S3 state bucket + DynamoDB lock table
│   ├── network/              # VPC, subnets, NAT, route tables
│   ├── security/             # IAM roles/policies, security groups
│   ├── alb/                  # Application Load Balancer + target group
│   └── compute/              # Launch template, ASG, scaling policies
├── envs/
│   ├── dev/                  # thin root module wiring all modules (dev)
│   └── prod/                 # same wiring, prod-sized variables
├── ansible/                  # playbook + inventory template consumed post-provision
└── .github/workflows/        # CI/CD pipeline using OIDC (no AWS access keys)
```

## How to use

```bash
# 1) One-time per AWS account: create the remote state backend
cd modules/backend-bootstrap
terraform init && terraform apply

# 2) Deploy an environment
cd ../../envs/dev
terraform init      # uses backend.tf -> S3 + DynamoDB configured above
terraform plan
terraform apply
```

## Apply prerequisites

Before running `terraform apply`, confirm the following:

- AWS credentials are available via environment variables or AWS config/profile:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_DEFAULT_REGION`
- The S3 backend bucket and DynamoDB lock table configured in `envs/*/backend.tf` already exist and the credentials have permission to use them.
- The `app_secret_arn` variable is set for the environment. For `envs/dev`, set it with one of:
  - `export TF_VAR_app_secret_arn="arn:aws:secretsmanager:..."`
  - add the ARN to `envs/dev/terraform.tfvars`
- If you want the deployment in `ap-south-1`, set `TF_VAR_aws_region=ap-south-1` before `terraform apply`, because the `envs/dev` default is `us-east-1`.
- The AWS user/role must be allowed to create VPC, subnet, EC2, IAM, ALB, Security Group, ASG, and Secrets Manager resources.

Example run:

```bash
cd terraform-advanced-project/envs/dev
export TF_VAR_app_secret_arn="arn:aws:secretsmanager:ap-south-1:123456789012:secret:my-app-secret"
export TF_VAR_aws_region="ap-south-1"
terraform init
terraform plan
terraform apply
```

## Provider version policy

- The AWS provider is pinned in each environment under `envs/*/backend.tf` using `required_providers`.
- Current approved provider version is `hashicorp/aws` `~> 5.0`.
- Changes to the provider version must be made intentionally, reviewed by the team, and validated in CI.
- A repository-level guard script (`scripts/verify-provider-versions.sh`) checks all environment files on every pull request and fails the build if the pin changes.
- For a stronger lock, generate and commit `terraform.lock.hcl` after `terraform init`; Terraform then preserves the exact provider version and checksum across machines.
- For module versioning, pin shared modules with a git tag in the source URL and update tags only after review.

Read the full teaching guide on Terraform versioning here:

- `TERRAFORM_VERSIONING.md`

## Notes

- All resource names/ARNs are illustrative placeholders — replace
  account IDs, bucket names, and CIDR ranges before real use.
- The GitHub Actions workflow assumes an IAM role via OIDC
  (`aws-actions/configure-aws-credentials@v4` with `role-to-assume`)
  — no long-lived access keys are stored anywhere.
- This is a learning/reference scaffold, not a drop-in production deployment.
