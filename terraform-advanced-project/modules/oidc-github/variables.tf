variable "github_org" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "apply_policy_arn" {
  description = "A scoped policy ARN granting exactly what terraform apply needs — never AdministratorAccess"
  type        = string
}
