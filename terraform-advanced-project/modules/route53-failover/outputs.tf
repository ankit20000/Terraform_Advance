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
