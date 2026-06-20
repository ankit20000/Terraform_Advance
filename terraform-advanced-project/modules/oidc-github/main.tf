############################################
# GitHub OIDC module: registers GitHub as an
# identity provider in AWS IAM and creates the
# plan/apply roles assumed by GitHub Actions —
# no long-lived AWS access keys required.
############################################

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# --- Trust policy: only this repo, only this branch, can assume the role ---
data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

# Read-only role — used for `terraform plan` on pull requests
resource "aws_iam_role" "plan_role" {
  name               = "github-actions-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Elevated role — used for `terraform apply` only after merge to main
resource "aws_iam_role" "apply_role" {
  name               = "github-actions-terraform-apply"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}

resource "aws_iam_role_policy_attachment" "apply_admin_scoped" {
  role       = aws_iam_role.apply_role.name
  policy_arn = var.apply_policy_arn # scope this to your infra's actual needs, NOT AdministratorAccess
}
