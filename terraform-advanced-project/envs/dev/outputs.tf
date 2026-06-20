output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "asg_name" {
  value = module.compute.asg_name
}
