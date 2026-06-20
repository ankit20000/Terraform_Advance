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

## Provider version policy

- The AWS provider is pinned in each environment under `envs/*/backend.tf` using `required_providers`.
- Current approved provider version is `hashicorp/aws` `~> 5.0`.
- Changes to the provider version must be made intentionally, reviewed by the team, and validated in CI.
- A repository-level guard script checks all environment files on every pull request to ensure the provider version stays pinned.

## Notes

- All resource names/ARNs are illustrative placeholders — replace
  account IDs, bucket names, and CIDR ranges before real use.
- The GitHub Actions workflow assumes an IAM role via OIDC
  (`aws-actions/configure-aws-credentials@v4` with `role-to-assume`)
  — no long-lived access keys are stored anywhere.
- This is a learning/reference scaffold, not a drop-in production deployment.
