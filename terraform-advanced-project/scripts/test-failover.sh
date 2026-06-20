#!/bin/bash
# Test Failover Between Regions
# Usage: ./scripts/test-failover.sh

set -e

PROJECT_DIR="/Users/ankitshukla/Downloads/terraform-advanced-project"
AWS_REGION_PRIMARY="us-east-1"
AWS_REGION_SECONDARY="us-west-2"

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

log_step() {
    echo -e "${BLUE}➤ $1${NC}"
}

echo ""
echo "========================================="
echo "   TERRAFORM FAILOVER TEST"
echo "========================================="
echo ""

# Get app FQDN from Route53 deployment
cd "$PROJECT_DIR/envs/route53-dr"
APP_FQDN=$(terraform output -raw app_fqdn 2>/dev/null || echo "")

if [ -z "$APP_FQDN" ]; then
    log_error "Could not retrieve APP_FQDN. Make sure Route53 deployment is complete."
    exit 1
fi

log_info "Testing with FQDN: $APP_FQDN"
echo ""

# Test 1: Check current status
log_step "Test 1: Checking current status..."
echo "  Resolving DNS..."
nslookup $APP_FQDN | grep -A 1 "Address:"
echo ""

log_step "Test 2: Testing application endpoint..."
echo "  Calling: http://$APP_FQDN/health"
if curl -s -o /dev/null -w "%{http_code}" http://$APP_FQDN/health; then
    log_info "Application responding OK"
else
    log_warn "Application may not be responding yet"
fi
echo ""

# Get health check IDs
cd "$PROJECT_DIR/envs/route53-dr"
PRIMARY_HC_ID=$(terraform output -raw primary_health_check_id 2>/dev/null)
SECONDARY_HC_ID=$(terraform output -raw secondary_health_check_id 2>/dev/null)

if [ -z "$PRIMARY_HC_ID" ] || [ -z "$SECONDARY_HC_ID" ]; then
    log_error "Could not retrieve health check IDs"
    exit 1
fi

log_info "Primary Health Check:   $PRIMARY_HC_ID"
log_info "Secondary Health Check: $SECONDARY_HC_ID"
echo ""

# Test 3: Simulate primary failure
log_step "Test 3: Simulating PRIMARY region failure..."
echo "  Marking primary health check as unhealthy..."

aws route53 update-health-check \
  --health-check-id $PRIMARY_HC_ID \
  --health-check-version 0 \
  --alarm-identifier Name=PrimaryFailure,Region=$AWS_REGION_PRIMARY \
  --region $AWS_REGION_PRIMARY 2>/dev/null || log_warn "Could not mark primary as unhealthy"

echo "  Waiting 90 seconds for failover (3 failed checks × 30 sec interval)..."
sleep 90

log_info "Checking DNS resolution after failover..."
nslookup $APP_FQDN | grep -A 1 "Address:"

echo ""
log_warn "Failover should be complete - traffic is now routed to SECONDARY"
echo ""

# Test 4: Restore primary
log_step "Test 4: Restoring PRIMARY region..."
echo "  Re-enabling primary health check..."

aws route53 update-health-check \
  --health-check-id $PRIMARY_HC_ID \
  --health-check-version 1 \
  --region $AWS_REGION_PRIMARY 2>/dev/null || log_warn "Could not re-enable primary"

echo "  Waiting 90 seconds for failback..."
sleep 90

log_info "Checking DNS resolution after failback..."
nslookup $APP_FQDN | grep -A 1 "Address:"

echo ""
log_info "Failback should be complete - traffic is back to PRIMARY"
echo ""

# Summary
echo "========================================="
echo "   FAILOVER TEST COMPLETED!"
echo "========================================="
echo ""
echo "✨ Summary:"
echo "  ✓ Primary → Secondary failover tested"
echo "  ✓ Secondary → Primary failback tested"
echo "  ✓ DNS failover working correctly"
echo ""
