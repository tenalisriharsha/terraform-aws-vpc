#!/usr/bin/env bash
# Regression test for issue #12.
#
# Every other scalar input to this module (name, cidr_block, azs) has a
# validation block that fails fast at plan time with a clear,
# module-authored error naming the offending variable (see variables.tf).
# flow_logs_retention_days has no validation at all, even though AWS
# CloudWatch Logs only accepts a fixed set of retention values. A bad value
# (e.g. 45) currently survives the whole plan and only fails deep inside the
# real AWS provider's own schema check, with an error that points at
# .terraform/modules/vpc/main.tf (the caller's downloaded copy of this
# module) instead of naming flow_logs_retention_days.
#
# tests/vpc.tftest.hcl cannot catch this: it uses mock_provider, which never
# runs the real aws provider's attribute-level validation, so a bad
# retention value plans cleanly there regardless of whether this module
# validates it. This test instead consumes the module the way a real caller
# does (source = <repo>, real aws provider, dummy credentials so no AWS
# account or network calls are involved) and asserts that a bad retention
# value is rejected by a module-authored error naming the variable, before
# any resource is planned.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $1" >&2; exit 1; }

if ! command -v terraform >/dev/null 2>&1; then
  echo "SKIP: terraform is not available." >&2
  exit 0
fi

workdir="$(mktemp -d)"
cleanup() { rm -rf "$workdir"; }
trap cleanup EXIT

cat > "$workdir/main.tf" <<EOF
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

module "vpc" {
  source = "$repo_root"

  name       = "repro"
  cidr_block = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  flow_logs_retention_days = 45
}
EOF

# Reuse this checkout's already-downloaded aws provider when present
# (.terraform/ is gitignored, so this is only a local/offline convenience;
# a fresh CI checkout falls through to a normal network init).
init_env=()
if [ -d "$repo_root/.terraform/providers" ]; then
  init_env=(env "TF_PLUGIN_CACHE_DIR=$repo_root/.terraform/providers")
fi

if ! "${init_env[@]}" terraform -chdir="$workdir" init -input=false -backend=false >"$workdir/init.log" 2>&1; then
  echo "SKIP: terraform init failed (likely no network access to the provider registry)." >&2
  cat "$workdir/init.log" >&2
  exit 0
fi

output="$(terraform -chdir="$workdir" plan -input=false 2>&1)" && exit_code=0 || exit_code=$?

[ "$exit_code" -ne 0 ] \
  || fail "terraform plan unexpectedly succeeded with flow_logs_retention_days = 45; expected it to be rejected."

if grep -q 'Plan:.*to add' <<<"$output"; then
  fail "terraform plan got as far as planning resources before failing on flow_logs_retention_days = 45; expected a fail-fast module validation error. Output:
$output"
fi

if grep -q 'retention_in_days to be one of' <<<"$output"; then
  fail "terraform plan failed with the raw AWS provider schema error for retention_in_days instead of a module-authored flow_logs_retention_days error. Output:
$output"
fi

grep -qi 'flow_logs_retention_days' <<<"$output" \
  || fail "terraform plan failed, but the error does not name flow_logs_retention_days as the expected module-authored validation error would. Output:
$output"

echo "PASS: flow_logs_retention_days = 45 is rejected by a module-authored, fail-fast validation error."
