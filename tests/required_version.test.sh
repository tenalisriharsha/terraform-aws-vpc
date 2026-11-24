#!/usr/bin/env bash
# Regression test for issue #9.
#
# versions.tf declares `required_version = ">= 1.6.0"`, but
# tests/vpc.tftest.hcl uses `mock_provider`, a Terraform 1.7+ feature. On a
# fresh clone with Terraform 1.6.x installed, the very first documented
# quick-start command, `terraform init -backend=false` run from the repo
# root, never reaches the module: Terraform parses the whole configuration
# (including tests/vpc.tftest.hcl) before checking required_version, so it
# fails with a generic "Unsupported block type" parse error instead of a
# clear version-constraint message.
#
# This test runs that exact command against a real Terraform 1.6.6 binary
# (via Docker, since the version installed in this environment is newer)
# and asserts that the failure is a version-constraint rejection pointing at
# versions.tf, not a parse error pointing at tests/vpc.tftest.hcl. That is
# only possible once required_version excludes 1.6.x (e.g. ">= 1.7.0"),
# which makes Terraform itself reject the old binary before it ever parses
# the test file.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
old_tf_image="hashicorp/terraform:1.6.6"
container_name="tf-required-version-regression-9"

fail() { echo "FAIL: $1" >&2; exit 1; }

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker is not available; cannot exercise a real Terraform 1.6.x binary." >&2
  exit 0
fi

if ! docker image inspect "$old_tf_image" >/dev/null 2>&1; then
  if ! docker pull "$old_tf_image" >/dev/null 2>&1; then
    echo "SKIP: could not obtain $old_tf_image (no local image, pull failed)." >&2
    exit 0
  fi
fi

docker rm -f "$container_name" >/dev/null 2>&1 || true

workdir="$(mktemp -d)"
cleanup() {
  docker rm -f "$container_name" >/dev/null 2>&1 || true
  rm -rf "$workdir"
}
trap cleanup EXIT

# Copy the repo (minus VCS/local Terraform state) into a scratch dir so the
# container never writes .terraform/ or anything else into the real checkout.
tar -C "$repo_root" --exclude='.git' --exclude='.terraform' --exclude='*.tfstate*' -cf - . \
  | tar -C "$workdir" -xf -

output="$(docker run --rm --name "$container_name" \
  -v "$workdir:/workspace" -w /workspace \
  --entrypoint terraform "$old_tf_image" init -backend=false 2>&1)" && exit_code=0 || exit_code=$?

[ "$exit_code" -ne 0 ] \
  || fail "terraform init -backend=false unexpectedly succeeded on Terraform 1.6.6; expected it to be rejected by required_version."

if grep -q 'Unsupported block type' <<<"$output"; then
  fail "terraform init -backend=false failed with a tests/vpc.tftest.hcl parse error (mock_provider needs Terraform 1.7+), not a required_version mismatch. Output:
$output"
fi

if grep -qi 'tests/vpc.tftest.hcl' <<<"$output"; then
  fail "terraform init -backend=false still fails while parsing tests/vpc.tftest.hcl instead of being rejected up front by required_version. Output:
$output"
fi

grep -qi 'required_version\|Unsupported Terraform Core version' <<<"$output" \
  || fail "terraform init -backend=false failed, but not with a required_version/version-constraint error as expected. Output:
$output"

echo "PASS: terraform init -backend=false on Terraform 1.6.6 is rejected by required_version, not by a tests/vpc.tftest.hcl parse error."
