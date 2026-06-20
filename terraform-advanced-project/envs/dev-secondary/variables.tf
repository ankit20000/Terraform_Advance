variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "app_secret_arn" {
  description = "ARN of the dev app secret in Secrets Manager"
  type        = string
}
