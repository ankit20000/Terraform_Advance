# Quick Start: Execute Multi-Region Setup

## 🚀 FASTEST WAY TO DEPLOY (5 minutes)

### Option A: Using Automation Script (Recommended)
```bash
# 1. Navigate to project
cd /Users/ankitshukla/Downloads/terraform-advanced-project

# 2. Make scripts executable
chmod +x scripts/*.sh

# 3. Set your AWS credentials
export AWS_PROFILE=default
export ROUTE53_ZONE_ID=Z1234567890ABC  # Replace with your zone ID

# 4. Run deployment script (automated)
./scripts/deploy-multi-region.sh
```

**That's it! All regions + Route53 will be deployed automatically.**

---

## 📋 MANUAL EXECUTION (If you prefer step-by-step)

### Step 1: Prerequisites Setup (1 min)
```bash
cd /Users/ankitshukla/Downloads/terraform-advanced-project

# Verify AWS CLI is configured
aws sts get-caller-identity

# Verify Terraform is installed
terraform version
```

### Step 2: Create State Backend (2 min)
```bash
# Primary region buckets
aws s3 mb s3://mycompany-tf-state-dev-primary --region us-east-1
aws s3api put-bucket-versioning --bucket mycompany-tf-state-dev-primary \
  --versioning-configuration Status=Enabled --region us-east-1

# Secondary region buckets
aws s3 mb s3://mycompany-tf-state-dev-secondary --region us-west-2
aws s3api put-bucket-versioning --bucket mycompany-tf-state-dev-secondary \
  --versioning-configuration Status=Enabled --region us-west-2

# Create lock tables
aws dynamodb create-table --table-name terraform-state-lock-primary \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region us-east-1

aws dynamodb create-table --table-name terraform-state-lock-secondary \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region us-west-2
```

### Step 3: Deploy Primary Region (8 min)
```bash
cd envs/dev

terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan

# Save outputs
terraform output > outputs.json
PRIMARY_ALB=$(terraform output -raw alb_dns_name)
PRIMARY_ZONE=$(terraform output -raw alb_zone_id)

echo "Primary ALB: $PRIMARY_ALB"
echo "Primary Zone: $PRIMARY_ZONE"
```

### Step 4: Deploy Secondary Region (8 min)
```bash
cd ../dev-secondary

terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan

# Save outputs
terraform output > outputs.json
SECONDARY_ALB=$(terraform output -raw alb_dns_name)
SECONDARY_ZONE=$(terraform output -raw alb_zone_id)

echo "Secondary ALB: $SECONDARY_ALB"
echo "Secondary Zone: $SECONDARY_ZONE"
```

### Step 5: Deploy Route53 Failover (5 min)
```bash
# Update the tfvars file with actual values
cd ../route53-dr
cat > terraform.tfvars <<EOF
route53_zone_id       = "Z1234567890ABC"
app_dns_name          = "myapp.example.com"
primary_alb_dns       = "$PRIMARY_ALB"
primary_alb_zone_id   = "$PRIMARY_ZONE"
secondary_alb_dns     = "$SECONDARY_ALB"
secondary_alb_zone_id = "$SECONDARY_ZONE"
EOF

terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan

APP_FQDN=$(terraform output -raw app_fqdn)
echo "✅ Application available at: $APP_FQDN"
```

---

## ✅ VERIFICATION COMMANDS

### Check Status
```bash
# Run status check script
./scripts/status-check.sh

# Or manually:
cd envs/dev
terraform output

cd ../dev-secondary
terraform output

cd ../route53-dr
terraform output
```

### Test Application
```bash
# Get the app FQDN
APP_FQDN=$(cd envs/route53-dr && terraform output -raw app_fqdn)

# Test DNS resolution
nslookup $APP_FQDN

# Test application endpoint
curl -v http://$APP_FQDN/health

# Check HTTP response
curl -I http://$APP_FQDN/health
```

### Health Check Status
```bash
# Get health check IDs
cd envs/route53-dr
PRIMARY_HC=$(terraform output -raw primary_health_check_id)
SECONDARY_HC=$(terraform output -raw secondary_health_check_id)

# Check primary health
aws route53 get-health-check-status --health-check-id $PRIMARY_HC --region us-east-1

# Check secondary health
aws route53 get-health-check-status --health-check-id $SECONDARY_HC --region us-west-1
```

---

## 🧪 TEST FAILOVER

### Automated Failover Test
```bash
./scripts/test-failover.sh
```

### Manual Failover Test
```bash
cd envs/route53-dr

# Get health check IDs
PRIMARY_HC=$(terraform output -raw primary_health_check_id)
SECONDARY_HC=$(terraform output -raw secondary_health_check_id)
APP_FQDN=$(terraform output -raw app_fqdn)

# Test current state
echo "=== Before failover ==="
nslookup $APP_FQDN

# Simulate primary failure
echo "=== Marking primary as unhealthy ==="
aws route53 update-health-check --health-check-id $PRIMARY_HC \
  --health-check-version 0 --region us-east-1

# Wait for failover
echo "=== Waiting 90 seconds for failover... ==="
sleep 90

# Check DNS after failover
echo "=== After failover ==="
nslookup $APP_FQDN

# Restore primary
echo "=== Restoring primary ==="
aws route53 update-health-check --health-check-id $PRIMARY_HC \
  --region us-east-1

sleep 90

# Check DNS after failback
echo "=== After failback ==="
nslookup $APP_FQDN
```

---

## 🗑️ CLEANUP (If needed)

### Destroy All Infrastructure
```bash
# Destroy in reverse order

# 1. Destroy Route53
cd envs/route53-dr
terraform destroy -auto-approve

# 2. Destroy secondary region
cd ../dev-secondary
terraform destroy -auto-approve

# 3. Destroy primary region
cd ../dev
terraform destroy -auto-approve

# 4. Empty S3 buckets
aws s3 rm s3://mycompany-tf-state-dev-primary --recursive --region us-east-1
aws s3 rb s3://mycompany-tf-state-dev-primary --region us-east-1

aws s3 rm s3://mycompany-tf-state-dev-secondary --recursive --region us-west-2
aws s3 rb s3://mycompany-tf-state-dev-secondary --region us-west-2

# 5. Delete DynamoDB tables
aws dynamodb delete-table --table-name terraform-state-lock-primary --region us-east-1
aws dynamodb delete-table --table-name terraform-state-lock-secondary --region us-west-2
```

---

## 📊 DEPLOYMENT TIMELINE

```
Total Time: ~32 minutes

├─ Prerequisites       (1 min)
├─ Backend Setup       (2 min)
├─ Primary Deploy      (8 min)
├─ Secondary Deploy    (8 min)
├─ Route53 Setup       (5 min)
├─ Verification        (2 min)
└─ Testing             (5 min)
```

---

## 📁 FILE STRUCTURE CREATED

```
terraform-advanced-project/
├── envs/
│   ├── dev/                          # Primary (us-east-1)
│   │   ├── main.tf (existing)
│   │   ├── backend.tf (existing)
│   │   ├── variables.tf (existing)
│   │   └── outputs.tf (existing)
│   │
│   ├── dev-secondary/                # NEW - Secondary (us-west-2)
│   │   ├── main.tf
│   │   ├── backend.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   │
│   └── route53-dr/                   # NEW - Route53 Failover
│       ├── main.tf
│       ├── backend.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
│
├── modules/
│   └── route53-failover/             # NEW - Route53 Module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── scripts/                          # NEW - Helper Scripts
│   ├── deploy-multi-region.sh
│   ├── test-failover.sh
│   └── status-check.sh
│
├── .github/workflows/
│   └── terraform-multi-region.yml    # NEW - CI/CD Pipeline
│
└── MULTI_REGION_SETUP_GUIDE.md       # NEW - This guide
```

---

## 🔑 KEY VALUES TO REMEMBER

```bash
# AWS Regions
Primary Region:     us-east-1
Secondary Region:   us-west-2

# S3 Buckets
Primary State:      mycompany-tf-state-dev-primary
Secondary State:    mycompany-tf-state-dev-secondary

# DynamoDB Tables
Primary Lock:       terraform-state-lock-primary
Secondary Lock:     terraform-state-lock-secondary

# Environment Names
Primary Prefix:     myapp-dev
Secondary Prefix:   myapp-dev-secondary

# VPC CIDR Blocks
Primary:            10.0.0.0/16
Secondary:          10.1.0.0/16

# Application Port
Default:            8080
```

---

## ⚡ QUICK REFERENCE COMMANDS

```bash
# View all infrastructure state
cd envs/dev && terraform show

# View specific resource
cd envs/dev && terraform state show aws_lb.this

# Get output values
cd envs/route53-dr && terraform output

# Refresh state
cd envs/dev && terraform refresh

# Plan changes only (no apply)
cd envs/dev && terraform plan

# Format all files
terraform fmt -recursive

# Validate syntax
terraform validate -recursive

# Count resources
terraform state list | wc -l

# List all resources
terraform state list
```

---

## 🎯 WHAT THIS SETUP GIVES YOU

✅ **High Availability**
  - Active primary + standby secondary region
  - Automatic failover via Route53
  - RTO: ~90 seconds
  - RPO: Near-zero (continuous replication possible)

✅ **Disaster Recovery**
  - Separate AWS regions (us-east-1, us-west-2)
  - State files replicated
  - Infrastructure as Code for quick recovery

✅ **Scalability**
  - Auto Scaling Groups in both regions
  - CPU-based scaling policies
  - Load balancing across AZs

✅ **Security**
  - IAM least-privilege policies
  - Security groups restricting traffic
  - Encrypted state files
  - No hardcoded credentials (OIDC ready)

✅ **Automation**
  - Terraform modules for reusability
  - CI/CD ready with GitHub Actions
  - Infrastructure as Code best practices

---

## 🆘 TROUBLESHOOTING

```bash
# Issue: Terraform init fails
# Solution: Check AWS credentials
aws sts get-caller-identity

# Issue: S3 bucket already exists
# Solution: Use unique bucket names (add your company name)

# Issue: Health check fails
# Solution: Ensure /health endpoint responds with 200 status

# Issue: Route53 doesn't failover
# Solution: Check health check IDs and ALB security groups

# Issue: DNS not resolving
# Solution: 
#   1. Verify hosted zone ID
#   2. Check Route53 records are created
#   3. Allow DNS propagation (up to 5 minutes)

# Check logs
# Terraform logs
export TF_LOG=DEBUG
terraform apply

# AWS CLI debugging
aws ... --debug
```

---

## 📞 SUPPORT COMMANDS

```bash
# Get account ID
aws sts get-caller-identity --query Account --output text

# List Route53 hosted zones
aws route53 list-hosted-zones

# List Route53 records in zone
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC

# Check EC2 instances in region
aws ec2 describe-instances --region us-east-1 --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name}'

# Check Load Balancers
aws elbv2 describe-load-balancers --region us-east-1

# Check Security Groups
aws ec2 describe-security-groups --region us-east-1 --filters Name=group-name,Values=myapp-dev*
```

---

**You're all set! Start with the automation script for fastest deployment.** ✨
