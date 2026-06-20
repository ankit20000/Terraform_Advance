# Multi-Region Deployment Checklist

Use this checklist to ensure everything is ready before deploying to production.

---

## 📋 PRE-DEPLOYMENT

### AWS Account Setup
- [ ] AWS Account created and active
- [ ] AWS credentials configured (`aws configure`)
- [ ] Verify account ID: `aws sts get-caller-identity`
- [ ] Verify account has permissions for EC2, ALB, Route53, S3, DynamoDB, IAM
- [ ] Budget alerts configured (prevent unexpected costs)

### Development Environment
- [ ] Terraform v1.6.0+ installed (`terraform version`)
- [ ] AWS CLI v2 installed (`aws --version`)
- [ ] Git configured with SSH keys
- [ ] Docker installed (optional, for local testing)
- [ ] Text editor/IDE setup (VS Code recommended)

### GitHub/Version Control
- [ ] Repository created
- [ ] `.gitignore` file includes:
  ```
  *.tfstate*
  .terraform/
  terraform.tfvars (contains secrets!)
  .env
  ```
- [ ] GitHub Actions permissions enabled
- [ ] OIDC role configured in AWS (if using GitHub Actions)

### Network Planning
- [ ] Choose primary region: `us-east-1` ✓
- [ ] Choose secondary region: `us-west-2` ✓
- [ ] Primary VPC CIDR: `10.0.0.0/16` ✓
- [ ] Secondary VPC CIDR: `10.1.0.0/16` ✓
- [ ] Public subnet CIDRs planned
- [ ] Private subnet CIDRs planned
- [ ] Document IP allocation for future use

### DNS Planning
- [ ] Domain name registered: `myapp.example.com`
- [ ] Route53 hosted zone created
- [ ] Hosted Zone ID obtained: `Z1234567890ABC`
- [ ] Update nameservers in domain registrar (if needed)
- [ ] Verify DNS propagation

### Application Planning
- [ ] Application port defined: `8080`
- [ ] `/health` endpoint exists and returns 200 status
- [ ] Secrets prepared (API keys, DB passwords, etc.)
- [ ] Secrets Manager secrets created in both regions
- [ ] Application Docker image available (optional)
- [ ] Database schema deployed (if needed)

---

## 🏗️ INFRASTRUCTURE DEPLOYMENT

### Phase 1: Backend (State Management)

- [ ] S3 bucket created: `mycompany-tf-state-dev-primary`
  ```bash
  aws s3 mb s3://mycompany-tf-state-dev-primary --region us-east-1
  ```

- [ ] S3 versioning enabled for primary
  ```bash
  aws s3api put-bucket-versioning --bucket mycompany-tf-state-dev-primary \
    --versioning-configuration Status=Enabled --region us-east-1
  ```

- [ ] S3 bucket created: `mycompany-tf-state-dev-secondary`
  ```bash
  aws s3 mb s3://mycompany-tf-state-dev-secondary --region us-west-2
  ```

- [ ] S3 versioning enabled for secondary
  ```bash
  aws s3api put-bucket-versioning --bucket mycompany-tf-state-dev-secondary \
    --versioning-configuration Status=Enabled --region us-west-2
  ```

- [ ] DynamoDB table created: `terraform-state-lock-primary`
  ```bash
  aws dynamodb create-table --table-name terraform-state-lock-primary \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST --region us-east-1
  ```

- [ ] DynamoDB table created: `terraform-state-lock-secondary`
  ```bash
  aws dynamodb create-table --table-name terraform-state-lock-secondary \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST --region us-west-2
  ```

### Phase 2: Primary Region Deployment

```bash
cd envs/dev
```

- [ ] Run `terraform init`
  - Check: ✓ Backend configured correctly
  - Check: ✓ DynamoDB lock acquired

- [ ] Run `terraform validate`
  - Check: ✓ No syntax errors

- [ ] Run `terraform fmt -recursive`
  - Check: ✓ All files formatted

- [ ] Run `terraform plan -out=tfplan`
  - Check: ✓ Plan looks correct
  - Check: ✓ No unexpected resource deletions
  - Check: ✓ All required resources present

- [ ] Review plan output:
  ```
  Plan: X to add, 0 to change, 0 to destroy
  ```

- [ ] Run `terraform apply tfplan`
  - ⏱️ Wait ~8 minutes for completion
  - Check: ✓ All resources created successfully

- [ ] Save outputs:
  ```bash
  terraform output > outputs.json
  PRIMARY_ALB=$(terraform output -raw alb_dns_name)
  PRIMARY_ZONE=$(terraform output -raw alb_zone_id)
  ```

- [ ] Verify resources created:
  ```bash
  # Check VPC
  aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Name,Values=myapp-dev-vpc"
  
  # Check instances
  aws ec2 describe-instances --region us-east-1 --filters "Name=tag:Name,Values=myapp-dev-*"
  
  # Check ALB
  aws elbv2 describe-load-balancers --region us-east-1 --query 'LoadBalancers[?contains(LoadBalancerName, `dev`)]'
  ```

- [ ] Test ALB endpoint:
  ```bash
  curl -I http://$PRIMARY_ALB/health
  # Expected: HTTP 200
  ```

### Phase 3: Secondary Region Deployment

```bash
cd envs/dev-secondary
```

- [ ] Run `terraform init`
  - Check: ✓ Backend configured correctly
  - Check: ✓ DynamoDB lock acquired (different table)

- [ ] Run `terraform validate`
  - Check: ✓ No syntax errors

- [ ] Run `terraform plan -out=tfplan`
  - Check: ✓ Plan shows different region resources

- [ ] Run `terraform apply tfplan`
  - ⏱️ Wait ~8 minutes

- [ ] Save outputs:
  ```bash
  terraform output > outputs.json
  SECONDARY_ALB=$(terraform output -raw alb_dns_name)
  SECONDARY_ZONE=$(terraform output -raw alb_zone_id)
  ```

- [ ] Test ALB endpoint:
  ```bash
  curl -I http://$SECONDARY_ALB/health
  # Expected: HTTP 200
  ```

### Phase 4: Route53 Failover Setup

```bash
cd envs/route53-dr
```

- [ ] Update `terraform.tfvars`:
  ```hcl
  route53_zone_id       = "Z1234567890ABC"
  app_dns_name          = "myapp.example.com"
  primary_alb_dns       = "PRIMARY_ALB_DNS_HERE"
  primary_alb_zone_id   = "PRIMARY_ZONE_ID_HERE"
  secondary_alb_dns     = "SECONDARY_ALB_DNS_HERE"
  secondary_alb_zone_id = "SECONDARY_ZONE_ID_HERE"
  ```

- [ ] Verify values are correct:
  ```bash
  cat terraform.tfvars
  ```

- [ ] Run `terraform init`
  - Check: ✓ Backend configured

- [ ] Run `terraform validate`
  - Check: ✓ No syntax errors

- [ ] Run `terraform plan -out=tfplan`
  - Check: ✓ 2 health checks created
  - Check: ✓ 2 Route53 records created

- [ ] Run `terraform apply tfplan`
  - ⏱️ Wait ~2 minutes

- [ ] Save outputs:
  ```bash
  terraform output > outputs.json
  APP_FQDN=$(terraform output -raw app_fqdn)
  ```

---

## ✅ POST-DEPLOYMENT VERIFICATION

### DNS Resolution

- [ ] DNS resolves to primary ALB:
  ```bash
  nslookup $APP_FQDN
  # Should return primary ALB IP
  ```

- [ ] DNS resolves consistently:
  ```bash
  for i in {1..5}; do nslookup $APP_FQDN; sleep 2; done
  # All should return same IP
  ```

- [ ] Different nameservers return same result:
  ```bash
  dig @8.8.8.8 $APP_FQDN
  dig @1.1.1.1 $APP_FQDN
  # Should match Route53 result
  ```

### Application Connectivity

- [ ] Primary application responds:
  ```bash
  curl -I http://$APP_FQDN/health
  # Expected: HTTP 200 OK
  ```

- [ ] Application returns data:
  ```bash
  curl http://$APP_FQDN/api/status | jq
  # Expected: Valid JSON response
  ```

- [ ] Response time acceptable (<1 second):
  ```bash
  curl -w "@curl-format.txt" -o /dev/null -s http://$APP_FQDN/health
  ```

### Health Checks

- [ ] Primary health check active:
  ```bash
  aws route53 get-health-check-status --health-check-id $PRIMARY_HC \
    --query 'HealthCheckObservations[0].StatusReport.Status'
  # Expected: "Success"
  ```

- [ ] Secondary health check active:
  ```bash
  aws route53 get-health-check-status --health-check-id $SECONDARY_HC \
    --query 'HealthCheckObservations[0].StatusReport.Status'
  # Expected: "Success"
  ```

### Infrastructure Health

- [ ] Primary instances running:
  ```bash
  aws ec2 describe-instances --region us-east-1 \
    --filters "Name=instance-state-name,Values=running" \
    --query 'length(Reservations[].Instances[])'
  # Expected: >= 1
  ```

- [ ] Secondary instances running:
  ```bash
  aws ec2 describe-instances --region us-west-2 \
    --filters "Name=instance-state-name,Values=running" \
    --query 'length(Reservations[].Instances[])'
  # Expected: >= 1
  ```

- [ ] ALB targets healthy:
  ```bash
  aws elbv2 describe-target-health --target-group-arn $PRIMARY_TG \
    --region us-east-1 --query 'TargetHealthDescriptions[].TargetHealth.State'
  # Expected: "healthy"
  ```

---

## 🧪 FAILOVER TESTING

### Pre-Test Checklist
- [ ] Testing scheduled and communicated
- [ ] Monitoring dashboards open
- [ ] Alert recipients notified
- [ ] Rollback plan documented
- [ ] Full team understands test procedure

### Test 1: Manual Failover Simulation

```bash
#!/bin/bash
# Simulate primary failure by marking health check unhealthy

PRIMARY_HC=$(cd envs/route53-dr && terraform output -raw primary_health_check_id)
APP_FQDN=$(cd envs/route53-dr && terraform output -raw app_fqdn)

echo "=== Test 1: Primary Failure Simulation ==="
echo ""
echo "Before failover:"
nslookup $APP_FQDN

echo ""
echo "Marking primary as unhealthy..."
aws route53 update-health-check --health-check-id $PRIMARY_HC \
  --health-check-version 0 --region us-east-1

echo "Waiting 90 seconds for failover..."
sleep 90

echo ""
echo "After failover:"
nslookup $APP_FQDN
# Should now point to secondary

echo ""
echo "Testing secondary application:"
curl -I http://$APP_FQDN/health
```

- [ ] Traffic switched to secondary region
- [ ] Application still responding
- [ ] No manual intervention needed

### Test 2: Automatic Failback

```bash
echo "=== Test 2: Failback to Primary ==="

echo "Re-enabling primary health check..."
aws route53 update-health-check --health-check-id $PRIMARY_HC \
  --region us-east-1

echo "Waiting 90 seconds for failback..."
sleep 90

echo ""
echo "After failback:"
nslookup $APP_FQDN
# Should point back to primary

echo ""
echo "Testing primary application:"
curl -I http://$APP_FQDN/health
```

- [ ] Traffic switched back to primary
- [ ] All systems normal

### Test 3: Regional Outage Simulation

- [ ] Stop primary region's ASG
  ```bash
  aws autoscaling set-desired-capacity \
    --auto-scaling-group-name myapp-dev-asg \
    --desired-capacity 0 --region us-east-1
  ```

- [ ] Monitor health check degradation
- [ ] Verify automatic failover to secondary
- [ ] Restore primary capacity
- [ ] Verify automatic failback

---

## 📊 PERFORMANCE VERIFICATION

### Load Testing (Optional)

- [ ] Run load test against primary:
  ```bash
  # Using Apache Bench
  ab -n 1000 -c 10 http://$APP_FQDN/api/status
  ```

- [ ] Monitor metrics:
  - [ ] CPU utilization on EC2 instances
  - [ ] ALB response time
  - [ ] Network throughput

- [ ] Auto-scaling triggers correctly:
  ```bash
  # Trigger scale-up
  # Monitor new instances launching
  watch -n 5 'aws autoscaling describe-auto-scaling-groups ...'
  ```

---

## 🔐 SECURITY VERIFICATION

### Access Controls

- [ ] IAM roles have least privileges
  ```bash
  aws iam get-role-policy --role-name myapp-dev-ec2-role --policy-name myapp-dev-ec2-least-priv
  ```

- [ ] Security groups restrict traffic
  ```bash
  aws ec2 describe-security-groups --region us-east-1 --filters "Name=tag:Name,Values=myapp-dev*"
  ```

- [ ] No hardcoded credentials in user data
  ```bash
  aws ec2 describe-launch-templates --region us-east-1 | grep -i "password\|key\|secret"
  ```

### Encryption

- [ ] S3 state buckets encrypted
  ```bash
  aws s3api get-bucket-encryption --bucket mycompany-tf-state-dev-primary
  ```

- [ ] DynamoDB encrypted (default: true)
- [ ] State files cannot be publicly accessed
  ```bash
  aws s3api get-bucket-public-access-block --bucket mycompany-tf-state-dev-primary
  ```

---

## 📝 DOCUMENTATION & HANDOVER

### Documentation Complete

- [ ] MULTI_REGION_SETUP_GUIDE.md reviewed
- [ ] QUICK_START.md updated with actual values
- [ ] modules/README.md reviewed
- [ ] Architecture diagram created/updated
- [ ] Runbooks documented:
  - [ ] Failover procedure
  - [ ] Failback procedure
  - [ ] Incident response
  - [ ] Scaling procedure

### Team Training

- [ ] Team trained on new setup
- [ ] DR procedures documented
- [ ] On-call rotation updated
- [ ] Escalation procedures defined

### Monitoring & Alerts

- [ ] CloudWatch dashboards created
  - [ ] Primary region metrics
  - [ ] Secondary region metrics
  - [ ] Route53 health check status

- [ ] SNS topics configured for alerts
- [ ] PagerDuty/Slack integration configured
- [ ] Alert thresholds tuned

---

## 🚀 PRODUCTION READINESS

### Go/No-Go Decision

- [ ] All tests passed ✓
- [ ] All checklist items completed ✓
- [ ] Team approval obtained ✓
- [ ] Business approval obtained ✓
- [ ] Maintenance window scheduled (if needed) ✓

### Backup & Recovery

- [ ] Database backups configured
- [ ] S3 cross-region replication enabled (optional)
- [ ] Disaster recovery runbook finalized
- [ ] Recovery Time Objective (RTO) documented: 90 seconds
- [ ] Recovery Point Objective (RPO) documented: <5 minutes

### Cost Monitoring

- [ ] AWS Budget alerts configured
- [ ] Cost breakdown calculated:
  - [ ] Primary region: $XXX/month
  - [ ] Secondary region: $XXX/month
  - [ ] Route53: ~$1.00/month
  - [ ] Total: $XXX/month

- [ ] Cost optimization opportunities identified

---

## 📞 POST-DEPLOYMENT SUPPORT

### Support Contacts

- [ ] Primary oncall contact:  ___________________
- [ ] Secondary oncall contact: ___________________
- [ ] Escalation contact: ___________________

### Issue Resolution

For issues encountered:
1. Check [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
2. Review CloudWatch logs
3. Contact oncall support
4. Escalate if needed

### Ongoing Maintenance

- [ ] Weekly: Check health check status
- [ ] Monthly: Review logs and metrics
- [ ] Quarterly: Test failover scenario
- [ ] Annually: Complete DR drill

---

## ✨ DEPLOYMENT COMPLETE

**Date Deployed**: _______________
**Deployed By**: _______________
**Approved By**: _______________
**Notes**: 

```
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
```

---

**Congratulations! You now have a production-ready multi-region disaster recovery setup!** 🎉
