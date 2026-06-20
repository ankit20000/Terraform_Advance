variable "name_prefix" {
  type = string
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
}

variable "app_dns_name" {
  description = "DNS name for the application (e.g., myapp.example.com)"
  type        = string
}

variable "primary_alb_dns" {
  description = "DNS name of primary region ALB"
  type        = string
}

variable "primary_alb_zone_id" {
  description = "Zone ID of primary region ALB"
  type        = string
}

variable "secondary_alb_dns" {
  description = "DNS name of secondary region ALB"
  type        = string
}

variable "secondary_alb_zone_id" {
  description = "Zone ID of secondary region ALB"
  type        = string
}

variable "app_port" {
  type    = number
  default = 8080
}
