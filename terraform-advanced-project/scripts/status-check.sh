#!/bin/bash
# Quick Status Check for Multi-Region Infrastructure
# Usage: ./scripts/status-check.sh

set -e

PROJECT_DIR="/Users/ankitshukla/Downloads/terraform-advanced-project"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

echo ""
log_section "TERRAFORM MULTI-REGION STATUS CHECK"

# Check primary
log_section "PRIMARY REGION (us-east-1)"
cd "$PROJECT_DIR/envs/dev"

if [ -f "terraform.tfstate" ]; then
    PRIM_VPC=$(terraform output vpc_id 2>/dev/null || echo "N/A")
    PRIM_ALB=$(terraform output alb_dns_name 2>/dev/null || echo "N/A")
    PRIM_ASG=$(terraform output asg_name 2>/dev/null || echo "N/A")
    
    log_info "VPC ID:     $PRIM_VPC"
    log_info "ALB DNS:    $PRIM_ALB"
    log_info "ASG Name:   $PRIM_ASG"
    
    # Check AWS resources
    INSTANCE_COUNT=$(aws ec2 describe-instances --region us-east-1 --filters "Name=tag:Name,Values=myapp-dev-asg-instance" "Name=instance-state-name,Values=running" --query 'length(Reservations[].Instances[])' --output text 2>/dev/null || echo "0")
    log_info "Running Instances: $INSTANCE_COUNT"
else
    log_error "Primary deployment not found"
fi

# Check secondary
log_section "SECONDARY REGION (us-west-2)"
cd "$PROJECT_DIR/envs/dev-secondary"

if [ -f "terraform.tfstate" ]; then
    SEC_VPC=$(terraform output vpc_id 2>/dev/null || echo "N/A")
    SEC_ALB=$(terraform output alb_dns_name 2>/dev/null || echo "N/A")
    SEC_ASG=$(terraform output asg_name 2>/dev/null || echo "N/A")
    
    log_info "VPC ID:     $SEC_VPC"
    log_info "ALB DNS:    $SEC_ALB"
    log_info "ASG Name:   $SEC_ASG"
    
    # Check AWS resources
    INSTANCE_COUNT=$(aws ec2 describe-instances --region us-west-2 --filters "Name=tag:Name,Values=myapp-dev-secondary-asg-instance" "Name=instance-state-name,Values=running" --query 'length(Reservations[].Instances[])' --output text 2>/dev/null || echo "0")
    log_info "Running Instances: $INSTANCE_COUNT"
else
    log_error "Secondary deployment not found"
fi

# Check Route53
log_section "ROUTE53 FAILOVER"
cd "$PROJECT_DIR/envs/route53-dr"

if [ -f "terraform.tfstate" ]; then
    APP_FQDN=$(terraform output app_fqdn 2>/dev/null || echo "N/A")
    log_info "Application FQDN: $APP_FQDN"
    
    # Check health
    PRIMARY_HC=$(terraform output primary_health_check_id 2>/dev/null || echo "N/A")
    SECONDARY_HC=$(terraform output secondary_health_check_id 2>/dev/null || echo "N/A")
    
    if [ "$PRIMARY_HC" != "N/A" ]; then
        HC_STATUS=$(aws route53 get-health-check-status --health-check-id $PRIMARY_HC --query 'HealthCheckObservations[0].StatusReport.Status' --output text 2>/dev/null || echo "UNKNOWN")
        log_info "Primary Health:   $HC_STATUS"
    fi
    
    if [ "$SECONDARY_HC" != "N/A" ]; then
        HC_STATUS=$(aws route53 get-health-check-status --health-check-id $SECONDARY_HC --query 'HealthCheckObservations[0].StatusReport.Status' --output text 2>/dev/null || echo "UNKNOWN")
        log_info "Secondary Health: $HC_STATUS"
    fi
else
    log_error "Route53 deployment not found"
fi

# S3 State Buckets
log_section "STATE BACKEND"
aws s3 ls s3://mycompany-tf-state-dev-primary --region us-east-1 2>/dev/null && log_info "Primary state bucket: ✓" || log_error "Primary state bucket: ✗"
aws s3 ls s3://mycompany-tf-state-dev-secondary --region us-west-2 2>/dev/null && log_info "Secondary state bucket: ✓" || log_error "Secondary state bucket: ✗"

echo ""
log_section "STATUS CHECK COMPLETE"
echo ""
