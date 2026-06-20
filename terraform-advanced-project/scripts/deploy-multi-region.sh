#!/bin/bash
# Deploy Multi-Region Terraform Infrastructure
# Usage: ./scripts/deploy-multi-region.sh

set -e

PROJECT_DIR="/Users/ankitshukla/Downloads/terraform-advanced-project"
ACCOUNT_ID="${AWS_ACCOUNT_ID:-123456789012}"
ROUTE53_ZONE_ID="${ROUTE53_ZONE_ID:-Z1234567890ABC}"
AWS_PROFILE="${AWS_PROFILE:-default}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Step 1: Validate prerequisites
echo ""
echo "========================================="
echo "   TERRAFORM MULTI-REGION DEPLOYMENT"
echo "========================================="
echo ""

log_info "Validating prerequisites..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found. Please install it."
    exit 1
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
    log_error "Terraform not found. Please install it."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity --profile $AWS_PROFILE > /dev/null 2>&1; then
    log_error "AWS credentials not configured. Please run 'aws configure'"
    exit 1
fi

log_info "Prerequisites validated"
echo ""

# Step 2: Create S3 buckets
log_info "Creating S3 state buckets..."

aws s3 mb s3://mycompany-tf-state-dev-primary --region us-east-1 2>/dev/null || log_warn "Primary bucket already exists"
aws s3api put-bucket-versioning \
  --bucket mycompany-tf-state-dev-primary \
  --versioning-configuration Status=Enabled \
  --region us-east-1

aws s3 mb s3://mycompany-tf-state-dev-secondary --region us-west-2 2>/dev/null || log_warn "Secondary bucket already exists"
aws s3api put-bucket-versioning \
  --bucket mycompany-tf-state-dev-secondary \
  --versioning-configuration Status=Enabled \
  --region us-west-2

log_info "S3 buckets configured"
echo ""

# Step 3: Create DynamoDB tables
log_info "Creating DynamoDB lock tables..."

aws dynamodb create-table \
  --table-name terraform-state-lock-primary \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1 2>/dev/null || log_warn "Primary lock table already exists"

aws dynamodb create-table \
  --table-name terraform-state-lock-secondary \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2 2>/dev/null || log_warn "Secondary lock table already exists"

log_info "DynamoDB tables configured"
echo ""

# Step 4: Deploy primary region
log_info "Deploying PRIMARY region (us-east-1)..."
cd "$PROJECT_DIR/envs/dev"

terraform init -input=false
terraform fmt -recursive
terraform validate
terraform plan -input=false -out=tfplan

terraform apply tfplan
terraform output > "$PROJECT_DIR/envs/dev/outputs.json"

PRIMARY_ALB_DNS=$(terraform output -raw alb_dns_name)
PRIMARY_ALB_ZONE=$(terraform output -raw alb_zone_id)

log_info "Primary region deployed"
log_info "Primary ALB: $PRIMARY_ALB_DNS"
echo ""

# Step 5: Deploy secondary region
log_info "Deploying SECONDARY region (us-west-2)..."
cd "$PROJECT_DIR/envs/dev-secondary"

terraform init -input=false
terraform fmt -recursive
terraform validate
terraform plan -input=false -out=tfplan

terraform apply tfplan
terraform output > "$PROJECT_DIR/envs/dev-secondary/outputs.json"

SECONDARY_ALB_DNS=$(terraform output -raw alb_dns_name)
SECONDARY_ALB_ZONE=$(terraform output -raw alb_zone_id)

log_info "Secondary region deployed"
log_info "Secondary ALB: $SECONDARY_ALB_DNS"
echo ""

# Step 6: Create Route53 terraform.tfvars
log_info "Configuring Route53 failover..."
cat > "$PROJECT_DIR/envs/route53-dr/terraform.tfvars" <<EOF
route53_zone_id       = "$ROUTE53_ZONE_ID"
app_dns_name          = "myapp.example.com"
primary_alb_dns       = "$PRIMARY_ALB_DNS"
primary_alb_zone_id   = "$PRIMARY_ALB_ZONE"
secondary_alb_dns     = "$SECONDARY_ALB_DNS"
secondary_alb_zone_id = "$SECONDARY_ALB_ZONE"
EOF

# Step 7: Deploy Route53
log_info "Deploying Route53 failover setup..."
cd "$PROJECT_DIR/envs/route53-dr"

terraform init -input=false
terraform fmt -recursive
terraform validate
terraform plan -input=false -out=tfplan

terraform apply tfplan
terraform output > "$PROJECT_DIR/envs/route53-dr/outputs.json"

APP_FQDN=$(terraform output -raw app_fqdn)

log_info "Route53 failover configured"
log_info "Application URL: $APP_FQDN"
echo ""

# Step 8: Summary
echo "========================================="
echo "   DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo "========================================="
echo ""
echo "📊 Deployment Summary:"
echo "  Primary Region:    us-east-1"
echo "  Primary ALB:       $PRIMARY_ALB_DNS"
echo "  Secondary Region:  us-west-2"
echo "  Secondary ALB:     $SECONDARY_ALB_DNS"
echo "  Application FQDN:  $APP_FQDN"
echo ""
echo "🔗 Next Steps:"
echo "  1. Update your DNS provider with: $APP_FQDN"
echo "  2. Test with: curl http://$APP_FQDN/health"
echo "  3. Monitor: AWS Route53 Console"
echo ""
echo "📝 Outputs saved to:"
echo "  - $PROJECT_DIR/envs/dev/outputs.json"
echo "  - $PROJECT_DIR/envs/dev-secondary/outputs.json"
echo "  - $PROJECT_DIR/envs/route53-dr/outputs.json"
echo ""
