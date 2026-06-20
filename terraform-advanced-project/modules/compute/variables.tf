variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "ami_name_filter" {
  description = "Prefix used when Packer tags/names the AMI"
  type        = string
  default     = "app-golden-image"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "instance_profile_name" {
  type = string
}

variable "app_sg_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "target_group_arn" {
  type = string
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 6
}

variable "target_cpu_utilization" {
  type    = number
  default = 60
}
