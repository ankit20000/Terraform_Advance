variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "app_secret_arn" {
  description = "ARN of the Secrets Manager secret the app is allowed to read"
  type        = string
}
