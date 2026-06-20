variable "route53_zone_id" {
  type = string
}

variable "app_dns_name" {
  type = string
}

variable "primary_alb_dns" {
  type = string
}

variable "primary_alb_zone_id" {
  type = string
}

variable "secondary_alb_dns" {
  type = string
}

variable "secondary_alb_zone_id" {
  type = string
}
