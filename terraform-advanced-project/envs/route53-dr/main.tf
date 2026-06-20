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
