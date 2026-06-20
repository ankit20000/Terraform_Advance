# Module Documentation

## Route53 Failover Module

### Overview
This module manages Route53 health checks and failover routing policies for disaster recovery setup across multiple AWS regions.

### Purpose
- **DNS Failover**: Automatically routes traffic to secondary region if primary fails
- **Health Monitoring**: Continuous health checks on both ALBs
- **Multi-Region HA**: Enables active-passive or active-active deployments

### Architecture

```
                    Route53 Hosted Zone
                           │
              ┌────────────┴────────────┐
              │                         │
        PRIMARY RECORD            SECONDARY RECORD
     (Active Failover)         (Backup Failover)
              │                         │
              ├─ Health Check          ├─ Health Check
              │  (ALB #1)              │  (ALB #2)
              │  - HTTP GET /health    │  - HTTP GET /health
              │  - Every 30 seconds    │  - Every 30 seconds
              │  - 3 failures → down   │  - 3 failures → down
              │                         │
        Primary ALB            Secondary ALB
       (us-east-1)            (us-west-2)
```

### Variables

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `name_prefix` | string | Yes | Naming prefix for resources |
| `route53_zone_id` | string | Yes | Route53 hosted zone ID (e.g., Z1234567890ABC) |
| `app_dns_name` | string | Yes | FQDN for the application (e.g., myapp.example.com) |
| `primary_alb_dns` | string | Yes | DNS name of primary ALB |
| `primary_alb_zone_id` | string | Yes | Zone ID of primary ALB |
| `secondary_alb_dns` | string | Yes | DNS name of secondary ALB |
| `secondary_alb_zone_id` | string | Yes | Zone ID of secondary ALB |
| `app_port` | number | No | Application port (default: 8080) |

### Outputs

| Output | Type | Description |
|--------|------|-------------|
| `primary_health_check_id` | string | Health check ID for primary ALB |
| `secondary_health_check_id` | string | Health check ID for secondary ALB |
| `app_fqdn` | string | Full FQDN of the application |

### Usage

```hcl
module "route53_failover" {
  source = "../../modules/route53-failover"

  name_prefix           = "myapp-dev"
  route53_zone_id       = "Z1234567890ABC"
  app_dns_name          = "myapp.example.com"
  primary_alb_dns       = "myapp-dev-alb-123456789.us-east-1.elb.amazonaws.com"
  primary_alb_zone_id   = "Z35SXDOTRQ7X7K"
  secondary_alb_dns     = "myapp-dev-secondary-alb-987654321.us-west-2.elb.amazonaws.com"
  secondary_alb_zone_id = "Z1H1FL5HABSF5"
  app_port              = 8080
}

output "app_url" {
  value = module.route53_failover.app_fqdn
}
```

### Health Check Configuration

**Interval**: 30 seconds
**Failure Threshold**: 3 consecutive failures
**Healthy Threshold**: 1 success

**Total failover time**: ~90 seconds
- 3 failures × 30 seconds = 90 seconds

### Failover Behavior

#### Scenario 1: Primary ALB Down
```
Time: 0:00  → Primary health check fails (attempt 1/3)
Time: 0:30  → Primary health check fails (attempt 2/3)
Time: 1:00  → Primary health check fails (attempt 3/3) → PRIMARY MARKED DOWN
Time: 1:30  → DNS query returns SECONDARY ALB IP
Time: 2:00  → All traffic now routed to secondary region
```

#### Scenario 2: Primary ALB Recovers
```
Time: 0:00  → Primary health check succeeds → PRIMARY MARKED UP
Time: 0:30  → DNS query returns PRIMARY ALB IP
Time: 1:00  → All traffic returned to primary region
```

### Best Practices

1. **Health Check Path**
   - Ensure `/health` endpoint returns HTTP 200
   - Make it lightweight and fast
   - Don't use authentication

2. **DNS TTL**
   - Set low TTL (60-300 seconds) for faster failover
   - Route53 health checks override TTL for failover

3. **Monitoring**
   - Set CloudWatch alarms on health check status
   - Monitor failover events
   - Log all DNS queries (optional via CloudTrail)

4. **Testing**
   - Test failover in non-production first
   - Document runbooks for incident response
   - Practice regular DR drills

### Cost Implications

**Route53 Pricing** (per health check):
- Standard: $0.50/month
- This module creates 2 health checks: ~$1.00/month

**Data Transfer**:
- Health checks: Negligible
- DNS queries: Free

### Troubleshooting

**Health check always failing**:
```bash
# Check ALB security group
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Verify /health endpoint
curl -I http://<alb-dns>/health

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:...
```

**DNS not resolving correctly**:
```bash
# Verify Route53 records
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC

# Check DNS propagation
dig myapp.example.com
nslookup myapp.example.com

# Check from different nameserver
dig @8.8.8.8 myapp.example.com
```

**Failover not working**:
```bash
# Check health check status
aws route53 get-health-check-status --health-check-id chk-xxxxx

# Check failover routing policy
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC | grep failover

# Verify both ALBs are accessible
curl -I http://<primary-alb>/health
curl -I http://<secondary-alb>/health
```

### Advanced Configurations

#### Option 1: Active-Active (Load Balancing)
```hcl
# Use GEOLOCATION or WEIGHTED routing instead of FAILOVER
# Route 50% to each region based on geographic location
```

#### Option 2: Custom Health Checks
```hcl
# Add custom health check logic beyond HTTP status
# Example: Check database connection, cache status, etc.
```

#### Option 3: CloudWatch Integration
```hcl
# Use CloudWatch alarms as health check triggers
# Example: Trigger failover based on CPU > 80%
```

### Related Modules

- **network**: Creates VPC, subnets, ALB in each region
- **compute**: Creates ASG with EC2 instances
- **alb**: Creates Application Load Balancer
- **security**: Creates IAM roles and security groups

### Maintenance

**Health Check Review**:
- Monthly: Verify health checks are passing
- Quarterly: Review and update thresholds
- Annually: Test full failover scenario

**DNS Records**:
- Verify CNAME/ALIAS records point to correct ALBs
- Check TTL settings are appropriate
- Monitor query patterns

---

## Multi-Region Environment Structure

### `envs/dev` - Primary Region (us-east-1)
```
Capacity: Full production
├─ EC2 Instances: 2-4 (t3.micro)
├─ AZs: 3
├─ VPC CIDR: 10.0.0.0/16
└─ State Backend: mycompany-tf-state-dev-primary
```

### `envs/dev-secondary` - Secondary Region (us-west-2)
```
Capacity: Minimal (standby)
├─ EC2 Instances: 1-4 (t3.micro)
├─ AZs: 3
├─ VPC CIDR: 10.1.0.0/16
└─ State Backend: mycompany-tf-state-dev-secondary
```

### `envs/route53-dr` - Failover Management
```
Manages DNS failover across regions
├─ Route53 Health Checks: 2
├─ Failover Records: 2
└─ State Backend: mycompany-tf-state-dev-primary
```

---

## Deployment Order

Always deploy in this order:

1. **Backend Infrastructure** (one-time)
   - S3 buckets for state
   - DynamoDB lock tables

2. **Primary Region** (`envs/dev`)
   - VPC, subnets, IGW
   - Security groups, IAM roles
   - ALB, target groups
   - ASG, EC2 instances

3. **Secondary Region** (`envs/dev-secondary`)
   - Same as primary (different AZs, VPCs, CIDR)
   - Lower capacity for cost optimization

4. **Route53 Failover** (`envs/route53-dr`)
   - After both regions are running
   - Requires ALB DNS names and zone IDs

---

## State Management

Each environment manages its own Terraform state:

| Environment | S3 Bucket | DynamoDB Table | Region |
|-------------|-----------|----------------|--------|
| dev | mycompany-tf-state-dev-primary | terraform-state-lock-primary | us-east-1 |
| dev-secondary | mycompany-tf-state-dev-secondary | terraform-state-lock-secondary | us-west-2 |
| route53-dr | mycompany-tf-state-dev-primary | terraform-state-lock-primary | us-east-1 |

**Benefit**: Prevents state conflicts and enables parallel deployments.

---

## Monitoring & Alerts

### CloudWatch Metrics to Monitor

```bash
# Route53 Health Checks
- HealthCheckStatus (0 = unhealthy, 1 = healthy)
- HealthCheckPercentageHealthy

# ALB
- TargetResponseTime
- UnHealthyHostCount
- HealthyHostCount
- RequestCount

# EC2
- CPUUtilization
- NetworkIn
- NetworkOut
```

### Recommended Alarms

```bash
# Primary region failure
CreateMetricAlarm:
  - MetricName: HealthCheckStatus
  - Statistic: Minimum
  - Threshold: 1
  - ComparisonOperator: LessThanThreshold
  - SNS Topic: ops-alerts

# Secondary region failure
CreateMetricAlarm:
  - MetricName: HealthCheckStatus
  - Statistic: Minimum
  - Threshold: 1
  - ComparisonOperator: LessThanThreshold
  - SNS Topic: ops-alerts

# No healthy targets
CreateMetricAlarm:
  - MetricName: HealthyHostCount
  - Statistic: Average
  - Threshold: 0
  - ComparisonOperator: LessThanOrEqualToThreshold
  - SNS Topic: critical-alerts
```

---

**For questions or issues, refer to the QUICK_START.md guide or MULTI_REGION_SETUP_GUIDE.md**
