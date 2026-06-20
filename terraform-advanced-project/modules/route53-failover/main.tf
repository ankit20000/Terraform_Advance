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
