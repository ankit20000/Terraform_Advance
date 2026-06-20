#!/usr/bin/env bash
set -euo pipefail

EXPECTED_PROVIDER_SOURCE="hashicorp/aws"
EXPECTED_PROVIDER_VERSION="~> 5.0"
FAILED=0

echo "Checking provider version pins in Terraform env files..."

for file in envs/*/backend.tf modules/backend-bootstrap/main.tf; do
  if [[ -f "$file" ]]; then
    echo "  - checking $file"
    if ! grep -qE "source\s*=\s*\"${EXPECTED_PROVIDER_SOURCE}\"" "$file"; then
      echo "ERROR: provider source does not match expected '${EXPECTED_PROVIDER_SOURCE}' in $file"
      FAILED=1
    fi
    if ! grep -qE "version\s*=\s*\"${EXPECTED_PROVIDER_VERSION}\"" "$file"; then
      echo "ERROR: provider version does not match expected '${EXPECTED_PROVIDER_VERSION}' in $file"
      FAILED=1
    fi
  fi
done

if [[ $FAILED -ne 0 ]]; then
  echo "\nProvider version check failed. Update the provider pin only after review."
  exit 1
fi

echo "Provider version pins are valid."
