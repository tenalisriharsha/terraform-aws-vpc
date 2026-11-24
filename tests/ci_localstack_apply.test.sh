#!/usr/bin/env bash
# Regression test for issue #3.
#
# Every existing run in tests/vpc.tftest.hcl uses `command = plan` against a
# mock_provider, and CI only runs `terraform validate`/`terraform test`. That
# means attributes AWS computes at apply time (resource IDs, ARNs, EIP
# addresses) are never actually checked. CI must also apply the complete
# example against LocalStack (or a sandbox account) and then destroy it.
#
# This test does not call AWS or LocalStack itself: it checks that the CI
# workflow(s) under .github/workflows actually wire up such a job, wherever
# it lives and whatever it's named.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflows_dir="$repo_root/.github/workflows"

fail() { echo "FAIL: $1" >&2; exit 1; }

[ -d "$workflows_dir" ] || fail "No workflows directory found at $workflows_dir"

shopt -s nullglob
workflow_files=("$workflows_dir"/*.yml "$workflows_dir"/*.yaml)
shopt -u nullglob
[ "${#workflow_files[@]}" -gt 0 ] || fail "No workflow files found under $workflows_dir"

combined="$(cat "${workflow_files[@]}")"

grep -Eq '(^|[^#])\bterraform([^#\n]*\b)?apply\b' <<<"$combined" \
  || fail "No workflow runs 'terraform apply' anywhere."

grep -Eq '(^|[^#])\bterraform([^#\n]*\b)?destroy\b' <<<"$combined" \
  || fail "No workflow runs 'terraform destroy' anywhere (applied resources would be left running)."

grep -q 'examples/complete' <<<"$combined" \
  || fail "No workflow targets the complete example for the apply/destroy run."

# The apply must run against LocalStack or an explicit sandbox AWS account,
# never against arbitrary/default AWS credentials.
grep -Eqi 'localstack' <<<"$combined" \
  || grep -q 'aws-actions/configure-aws-credentials' <<<"$combined" \
  || fail "No workflow configures a LocalStack endpoint or a sandbox AWS account for the apply run."

echo "PASS: CI applies and destroys the complete example against LocalStack or a sandbox account."
