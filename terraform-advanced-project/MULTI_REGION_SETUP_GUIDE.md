# Multi-Region Terraform Setup - Step-by-Step Execution Guide

## Prerequisites
- AWS Account with appropriate permissions
- Terraform >= 1.6.0
- AWS CLI configured
- GitHub repository setup
- Two AWS regions: `us-east-1` (Primary) and `us-west-2` (Secondary)

---

## 📋 PART 1: PRE-DEPLOYMENT SETUP (One-Time)

### Step 1.1: Create S3 Buckets for State (Primary Region)
```bash
# Navigate to workspace
cd /Users/ankitshukla/Downloads/terraform-advanced-project

# Create primary state bucket
aws s3 mb s3://mycompany-tf-state-dev-primary --region us-east-1
aws s3api put-bucket-versioning \
  --bucket mycompany-tf-state-dev-primary \
  --versioning-configuration Status=Enabled \
  --region us-east-1

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket mycompany-tf-state-dev-primary \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
  --region us-east-1

# Block public access
aws s3api put-public-access-block \
  --bucket mycompany-tf-state-dev-primary \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --region us-east-1

echo "✅ Primary state bucket created"
```

### Step 1.2: Create S3 Buckets for State (Secondary Region)
```bash
# Create secondary state bucket (destination for replication)
aws s3 mb s3://mycompany-tf-state-dev-secondary --region us-west-2
aws s3api put-bucket-versioning \
  --bucket mycompany-tf-state-dev-secondary \
  --versioning-configuration Status=Enabled \
  --region us-west-2

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket mycompany-tf-state-dev-secondary \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
  --region us-west-2

# Block public access
aws s3api put-public-access-block \
  --bucket mycompany-tf-state-dev-secondary \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --region us-west-2

echo "✅ Secondary state bucket created"
```

### Step 1.3: Create DynamoDB Lock Tables
```bash
# Primary region
aws dynamodb create-table \
  --table-name terraform-state-lock-primary \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# Secondary region
aws dynamodb create-table \
  --table-name terraform-state-lock-secondary \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2

echo "✅ DynamoDB lock tables created"
```

### Step 1.4: Create Route53 Hosted Zone (if not exists)
```bash
# Create hosted zone for DNS failover
aws route53 create-hosted-zone \
  --name myapp.example.com \
  --caller-reference $(date +%s) \
  --region us-east-1

# Note: Save the HostedZoneId from output (looks like: /hostedzone/Z1234567890ABC)
# You'll need this for the Route53 failover module

echo "✅ Route53 hosted zone created"
```

---

## 🏗️ PART 2: CREATE MULTI-REGION MODULE FILES

### Step 2.1: Create Secondary Environment Structure
```bash
# Create directory structure for secondary region
mkdir -p envs/dev-secondary
mkdir -p envs/prod-secondary
mkdir -p modules/route53-failover
mkdir -p modules/backup-replication

echo "✅ Directory structure created"
```

### Step 2.2: Create Dev Secondary Backend Configuration
**File**: `envs/dev-secondary/backend.tf`

```hcl
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
```

### Step 2.3: Create Dev Secondary Main Configuration
**File**: `envs/dev-secondary/main.tf`

```hcl
module "network" {
  source      = "../../modules/network"
  name_prefix = local.name_prefix
  vpc_cidr    = "10.1.0.0/16"  # Different CIDR for secondary region
  azs         = ["us-west-2a", "us-west-2b", "us-west-2c"]  # Secondary region AZs
}

module "security" {
  source          = "../../modules/security"
  name_prefix     = local.name_prefix
  vpc_id          = module.network.vpc_id
  app_port        = var.app_port
  app_secret_arn  = var.app_secret_arn
}

module "alb" {
  source            = "../../modules/alb"
  name_prefix       = local.name_prefix
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  app_port          = var.app_port
}

module "compute" {
  source                 = "../../modules/compute"
  name_prefix            = local.name_prefix
  environment            = "dev"
  instance_type          = "t3.micro"
  instance_profile_name  = module.security.instance_profile_name
  app_sg_id              = module.security.app_sg_id
  private_subnet_ids     = module.network.private_subnet_ids
  target_group_arn       = module.alb.target_group_arn
  desired_capacity       = 1  # Lower capacity for DR standby
  min_size               = 1
  max_size               = 4
}

locals {
  name_prefix = "myapp-dev-secondary"
}
```

### Step 2.4: Create Dev Secondary Variables
**File**: `envs/dev-secondary/variables.tf`

```hcl
variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "app_secret_arn" {
  description = "ARN of the dev app secret in Secrets Manager"
  type        = string
}
```

### Step 2.5: Create Dev Secondary Terraform Variables File
**File**: `envs/dev-secondary/terraform.tfvars`

```hcl
app_port       = 8080
app_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:dev/myapp-secret-ABC123"
```

---

## 🔄 PART 3: SETUP ROUTE53 FAILOVER MODULE

### Step 3.1: Create Route53 Failover Module
**File**: `modules/route53-failover/main.tf`

```hcl
# Primary ALB Health Check
resource "aws_route53_health_check" "primary_alb" {
  ip_address        = var.primary_alb_dns
  port              = var.app_port
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "${var.name_prefix}-primary-health-check"
  }
}

# Secondary ALB Health Check
resource "aws_route53_health_check" "secondary_alb" {
  ip_address        = var.secondary_alb_dns
  port              = var.app_port
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "${var.name_prefix}-secondary-health-check"
  }
}

# Primary DNS Record (Active)
resource "aws_route53_record" "app_primary" {
  zone_id = var.route53_zone_id
  name    = var.app_dns_name
  type    = "A"

  alias {
    name                   = var.primary_alb_dns
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
  }

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary_alb.id
  set_identifier  = "primary-us-east-1"
}

# Secondary DNS Record (Backup/Failover)
resource "aws_route53_record" "app_secondary" {
  zone_id = var.route53_zone_id
  name    = var.app_dns_name
  type    = "A"

  alias {
    name                   = var.secondary_alb_dns
    zone_id                = var.secondary_alb_zone_id
    evaluate_target_health = true
  }

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "secondary-us-west-2"
}

output "primary_health_check_id" {
  value = aws_route53_health_check.primary_alb.id
}

output "secondary_health_check_id" {
  value = aws_route53_health_check.secondary_alb.id
}
```

### Step 3.2: Create Route53 Variables
**File**: `modules/route53-failover/variables.tf`

```hcl
variable "name_prefix" {
  type = string
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
}

variable "app_dns_name" {
  description = "DNS name for the application (e.g., myapp.example.com)"
  type        = string
}

variable "primary_alb_dns" {
  description = "DNS name of primary region ALB"
  type        = string
}

variable "primary_alb_zone_id" {
  description = "Zone ID of primary region ALB"
  type        = string
}

variable "secondary_alb_dns" {
  description = "DNS name of secondary region ALB"
  type        = string
}

variable "secondary_alb_zone_id" {
  description = "Zone ID of secondary region ALB"
  type        = string
}

variable "app_port" {
  type    = number
  default = 8080
}
```

### Step 3.3: Create Route53 Outputs
**File**: `modules/route53-failover/outputs.tf`

```hcl
output "primary_health_check_id" {
  description = "Health check ID for primary region"
  value       = aws_route53_health_check.primary_alb.id
}

output "secondary_health_check_id" {
  description = "Health check ID for secondary region"
  value       = aws_route53_health_check.secondary_alb.id
}

output "app_fqdn" {
  description = "FQDN of the application"
  value       = aws_route53_record.app_primary.fqdn
}
```

---

## 🚀 PART 4: DEPLOYMENT STEPS

### Step 4.1: Deploy Primary Region (us-east-1)
```bash
cd envs/dev

# Initialize Terraform with remote backend
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out=tfplan-primary

# Review and approve
terraform apply tfplan-primary

# Save outputs
terraform output > primary-outputs.json

echo "✅ Primary region deployed"
```

### Step 4.2: Deploy Secondary Region (us-west-2)
```bash
cd ../dev-secondary

# Initialize Terraform with remote backend
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out=tfplan-secondary

# Review and approve
terraform apply tfplan-secondary

# Save outputs
terraform output > secondary-outputs.json

echo "✅ Secondary region deployed"
```

### Step 4.3: Extract ALB Information
```bash
cd /Users/ankitshukla/Downloads/terraform-advanced-project

# Extract primary ALB details
PRIMARY_ALB_DNS=$(cd envs/dev && terraform output -raw alb_dns_name)
PRIMARY_ALB_ZONE=$(cd envs/dev && terraform output -raw alb_zone_id)

# Extract secondary ALB details
SECONDARY_ALB_DNS=$(cd envs/dev-secondary && terraform output -raw alb_dns_name)
SECONDARY_ALB_ZONE=$(cd envs/dev-secondary && terraform output -raw alb_zone_id)

# Display for verification
echo "Primary ALB: $PRIMARY_ALB_DNS (Zone: $PRIMARY_ALB_ZONE)"
echo "Secondary ALB: $SECONDARY_ALB_DNS (Zone: $SECONDARY_ALB_ZONE)"
```

### Step 4.4: Create Route53 Failover Module Configuration
**File**: `envs/route53-dr/main.tf` (NEW - Separate env for Route53)

```hcl
module "route53_failover" {
  source = "../../modules/route53-failover"

  name_prefix           = "myapp-dev"
  route53_zone_id       = var.route53_zone_id
  app_dns_name          = var.app_dns_name
  primary_alb_dns       = var.primary_alb_dns
  primary_alb_zone_id   = var.primary_alb_zone_id
  secondary_alb_dns     = var.secondary_alb_dns
  secondary_alb_zone_id = var.secondary_alb_zone_id
  app_port              = 8080
}

output "app_fqdn" {
  value = module.route53_failover.app_fqdn
}
```

### Step 4.5: Create Route53 Variables File
**File**: `envs/route53-dr/variables.tf` (NEW)

```hcl
variable "route53_zone_id" {
  type = string
}

variable "app_dns_name" {
  type = string
}

variable "primary_alb_dns" {
  type = string
}

variable "primary_alb_zone_id" {
  type = string
}

variable "secondary_alb_dns" {
  type = string
}

variable "secondary_alb_zone_id" {
  type = string
}
```

### Step 4.6: Create Route53 Backend
**File**: `envs/route53-dr/backend.tf` (NEW)

```hcl
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
```

### Step 4.7: Deploy Route53 Failover
```bash
# Create Route53 tfvars file
cat > envs/route53-dr/terraform.tfvars <<EOF
route53_zone_id       = "Z1234567890ABC"  # Replace with your zone ID
app_dns_name          = "myapp.example.com"
primary_alb_dns       = "$PRIMARY_ALB_DNS"
primary_alb_zone_id   = "$PRIMARY_ALB_ZONE"
secondary_alb_dns     = "$SECONDARY_ALB_DNS"
secondary_alb_zone_id = "$SECONDARY_ALB_ZONE"
EOF

cd envs/route53-dr
mkdir -p envs/route53-dr

terraform init
terraform validate
terraform plan -out=tfplan-route53

terraform apply tfplan-route53

echo "✅ Route53 failover configured"
```

---

## ✅ PART 5: VERIFICATION & TESTING

### Step 5.1: Verify Infrastructure Health
```bash
# Check primary region health
aws route53 get-health-check-status \
  --health-check-id $(cd /Users/ankitshukla/Downloads/terraform-advanced-project && terraform -chdir=envs/route53-dr output -raw primary_health_check_id) \
  --region us-east-1

# Check secondary region health
aws route53 get-health-check-status \
  --health-check-id $(cd /Users/ankitshukla/Downloads/terraform-advanced-project && terraform -chdir=envs/route53-dr output -raw secondary_health_check_id) \
  --region us-east-1

echo "✅ Health checks verified"
```

### Step 5.2: Test DNS Failover
```bash
# Get the app FQDN
APP_FQDN=$(cd /Users/ankitshukla/Downloads/terraform-advanced-project && terraform -chdir=envs/route53-dr output -raw app_fqdn)

# Test DNS resolution (should point to primary)
nslookup $APP_FQDN

# Test application endpoint
curl -v http://$APP_FQDN/health

echo "✅ DNS and application endpoint verified"
```

### Step 5.3: Simulate Primary Region Failure (Test Failover)
```bash
# Stop primary ALB (simulates failure)
REGION=us-east-1
ALB_NAME=$(aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?contains(LoadBalancerName, `dev`)] | [0].LoadBalancerName' --output text)

# Mark primary health check as unhealthy
aws route53 update-health-check \
  --health-check-id $(cd /Users/ankitshukla/Downloads/terraform-advanced-project && terraform -chdir=envs/route53-dr output -raw primary_health_check_id) \
  --health-check-version 0 \
  --region us-east-1

# Wait 2 minutes for health check to fail
echo "Waiting for failover... (2 minutes)"
sleep 120

# Test DNS resolution (should now point to secondary)
nslookup $APP_FQDN

# Verify traffic goes to secondary
curl -v http://$APP_FQDN/health

echo "✅ Failover test completed successfully"
```

### Step 5.4: Restore Primary (Failback)
```bash
# Re-enable primary health check
aws route53 update-health-check \
  --health-check-id $(cd /Users/ankitshukla/Downloads/terraform-advanced-project && terraform -chdir=envs/route53-dr output -raw primary_health_check_id) \
  --enable-sni \
  --region us-east-1

# Wait for primary to be restored to active
sleep 120

# Verify traffic is back to primary
nslookup $APP_FQDN
curl -v http://$APP_FQDN/health

echo "✅ Failback completed successfully"
```

---

## 🔧 PART 6: CI/CD PIPELINE UPDATE

### Step 6.1: Create Multi-Region CI/CD Workflow
**File**: `.github/workflows/terraform-multi-region.yml`

```yaml
name: Terraform Multi-Region CI/CD (OIDC)

on:
  pull_request:
    paths:
      - "envs/**"
      - "modules/**"
  push:
    branches: [main]
    paths:
      - "envs/**"
      - "modules/**"

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  plan:
    name: Plan - ${{ matrix.env }}
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include:
          - env: dev
            env_dir: envs/dev
            aws_region: us-east-1
          - env: dev-secondary
            env_dir: envs/dev-secondary
            aws_region: us-west-2
          - env: route53-dr
            env_dir: envs/route53-dr
            aws_region: us-east-1

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions-terraform-plan
          aws-region: ${{ matrix.aws_region }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.5

      - name: Format check
        run: terraform -chdir=${{ matrix.env_dir }} fmt -check -recursive

      - name: Terraform init
        run: terraform -chdir=${{ matrix.env_dir }} init -input=false

      - name: Terraform validate
        run: terraform -chdir=${{ matrix.env_dir }} validate

      - name: Terraform plan
        run: terraform -chdir=${{ matrix.env_dir }} plan -input=false -no-color

  apply:
    name: Apply - ${{ matrix.env }}
    needs: plan
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: production
    strategy:
      matrix:
        include:
          - env: dev
            env_dir: envs/dev
            aws_region: us-east-1
          - env: dev-secondary
            env_dir: envs/dev-secondary
            aws_region: us-west-2
          - env: route53-dr
            env_dir: envs/route53-dr
            aws_region: us-east-1

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions-terraform-apply
          aws-region: ${{ matrix.aws_region }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.5

      - name: Terraform init
        run: terraform -chdir=${{ matrix.env_dir }} init -input=false

      - name: Terraform apply
        run: terraform -chdir=${{ matrix.env_dir }} apply -input=false -auto-approve
```

---

## 📊 PART 7: MONITORING & ALERTS

### Step 7.1: Create CloudWatch Alarms
```bash
# Primary ALB health check alarm
aws cloudwatch put-metric-alarm \
  --alarm-name myapp-dev-primary-health-check \
  --alarm-description "Alert when primary ALB health check fails" \
  --metric-name HealthCheckStatus \
  --namespace AWS/Route53 \
  --statistic Minimum \
  --period 60 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:alerts-topic \
  --region us-east-1

# Secondary ALB health check alarm
aws cloudwatch put-metric-alarm \
  --alarm-name myapp-dev-secondary-health-check \
  --alarm-description "Alert when secondary ALB health check fails" \
  --metric-name HealthCheckStatus \
  --namespace AWS/Route53 \
  --statistic Minimum \
  --period 60 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:us-west-2:123456789012:alerts-topic \
  --region us-west-2

echo "✅ CloudWatch alarms created"
```

---

## 📋 PART 8: CLEANUP & ROLLBACK

### Step 8.1: Destroy Infrastructure (if needed)
```bash
# Destroy Route53 records
cd envs/route53-dr
terraform destroy -auto-approve

# Destroy secondary region
cd ../dev-secondary
terraform destroy -auto-approve

# Destroy primary region
cd ../dev
terraform destroy -auto-approve

echo "✅ Infrastructure destroyed"
```

### Step 8.2: Delete State Buckets (Optional)
```bash
# Empty and delete primary bucket
aws s3 rm s3://mycompany-tf-state-dev-primary --recursive --region us-east-1
aws s3 rb s3://mycompany-tf-state-dev-primary --region us-east-1

# Empty and delete secondary bucket
aws s3 rm s3://mycompany-tf-state-dev-secondary --recursive --region us-west-2
aws s3 rb s3://mycompany-tf-state-dev-secondary --region us-west-2

echo "✅ State buckets deleted"
```

---

## 🎯 QUICK START SCRIPT

Save this as `deploy-multi-region.sh`:

```bash
#!/bin/bash
set -e

PROJECT_DIR="/Users/ankitshukla/Downloads/terraform-advanced-project"
ACCOUNT_ID="123456789012"  # Replace with your account
ROUTE53_ZONE_ID="Z1234567890ABC"  # Replace with your zone ID

cd $PROJECT_DIR

echo "=== Step 1: Creating S3 buckets ==="
./scripts/create-s3-buckets.sh

echo "=== Step 2: Creating DynamoDB tables ==="
./scripts/create-dynamodb-tables.sh

echo "=== Step 3: Deploying primary region ==="
cd envs/dev
terraform init
terraform apply -auto-approve
PRIMARY_ALB_DNS=$(terraform output -raw alb_dns_name)
PRIMARY_ALB_ZONE=$(terraform output -raw alb_zone_id)
cd $PROJECT_DIR

echo "=== Step 4: Deploying secondary region ==="
cd envs/dev-secondary
terraform init
terraform apply -auto-approve
SECONDARY_ALB_DNS=$(terraform output -raw alb_dns_name)
SECONDARY_ALB_ZONE=$(terraform output -raw alb_zone_id)
cd $PROJECT_DIR

echo "=== Step 5: Deploying Route53 failover ==="
cat > envs/route53-dr/terraform.tfvars <<EOF
route53_zone_id       = "$ROUTE53_ZONE_ID"
app_dns_name          = "myapp.example.com"
primary_alb_dns       = "$PRIMARY_ALB_DNS"
primary_alb_zone_id   = "$PRIMARY_ALB_ZONE"
secondary_alb_dns     = "$SECONDARY_ALB_DNS"
secondary_alb_zone_id = "$SECONDARY_ALB_ZONE"
EOF

cd envs/route53-dr
terraform init
terraform apply -auto-approve
cd $PROJECT_DIR

echo "✅ Multi-region deployment completed!"
echo "App URL: myapp.example.com"
```

---

## ✨ Summary

| Step | Command | Time |
|------|---------|------|
| 1 | Create S3 buckets | 1 min |
| 2 | Create DynamoDB | 1 min |
| 3 | Deploy primary | 10 min |
| 4 | Deploy secondary | 10 min |
| 5 | Deploy Route53 | 5 min |
| 6 | Test failover | 5 min |
| **Total** | **End-to-end** | **~32 min** |

---

## 🚨 Troubleshooting

```bash
# Check Terraform state
terraform state list

# View specific resource
terraform state show aws_lb.this

# Check AWS resources
aws ec2 describe-instances --region us-east-1
aws elbv2 describe-load-balancers --region us-east-1

# Check DynamoDB locks
aws dynamodb scan --table-name terraform-state-lock-primary

# Monitor failover
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC
```
