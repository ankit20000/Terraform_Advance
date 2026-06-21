# Terraform Versioning & Provider Locking

This document explains the safest way to teach Terraform version control for modules, Terraform CLI, and providers.

## 1. Terraform CLI version

Use the `required_version` block in your root module to control which Terraform binary can be used:

```hcl
terraform {
  required_version = ">= 1.6.0, < 2.0.0"
}
```

That prevents developers from running an unsupported Terraform CLI accidentally.

## 2. Module versioning using Git tags

If you share reusable modules from a git repository, pin the module source to a tag.
This makes module upgrades explicit and repeatable.

Example:

```hcl
module "network" {
  source = "git::https://github.com/ankit20000/Terraform_Advance.git//modules/network?ref=v1.0.0"
  name_prefix = "myapp"
}
```

- `//modules/network` selects the nested module path.
- `?ref=v1.0.0` pins the module to the exact git tag.

When you want to upgrade the module, create a new git tag:

```bash
git tag -a v1.1.0 -m "Release network module v1.1.0"
git push origin v1.1.0
```

Then update the root module source and test with `terraform init -upgrade` and `terraform plan`.

## 3. Provider version pinning with `required_providers`

Always pin provider source and version constraints in the same root module that uses the resources.
For example:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

This means:
- use the AWS provider from HashiCorp
- accept updates only within `5.0.x`

## 4. Provider lock file: `terraform.lock.hcl`

`terraform init` creates `.terraform.lock.hcl` automatically.
Commit this file to version control so every machine uses the same exact provider binary version and checksum.

That gives you two layers of protection:

1. `required_providers` restricts the allowed provider range.
2. `terraform.lock.hcl` freezes the exact provider version and checksum.

If someone changes the provider version in code, the following will happen:

- CI checks the `required_providers` configuration and fails if the version no longer matches the approved pin.
- `terraform init` will also detect a lock file mismatch and refuse to upgrade unless the lock file is intentionally refreshed.

## 5. How to upgrade a provider safely

When you want to move provider versions:

```bash
terraform init -upgrade
terraform plan
```

Review the updated `terraform.lock.hcl` diff and commit it together with the provider change.

## 6. Making changes fail if provider pin is modified

The strongest pattern is:

- pin provider version in `required_providers`
- commit `.terraform.lock.hcl`
- add a CI guard that verifies the provider pin has not changed
- require PR review and branch protection

This turns accidental provider changes into explicit, reviewable pull requests.

## 7. Example teaching notes

- `required_providers` = allowed provider range.
- `.terraform.lock.hcl` = exact version + checksum.
- `git tag` = exact module release.
- `terraform init -upgrade` = deliberate provider/module upgrade.

These are the three controls every Terraform team should understand.
