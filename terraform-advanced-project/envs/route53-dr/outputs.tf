output "app_fqdn" {
  value       = module.route53_failover.app_fqdn
  description = "Application FQDN"
}

output "primary_health_check_id" {
  value       = module.route53_failover.primary_health_check_id
  description = "Primary health check ID"
}

output "secondary_health_check_id" {
  value       = module.route53_failover.secondary_health_check_id
  description = "Secondary health check ID"
}
