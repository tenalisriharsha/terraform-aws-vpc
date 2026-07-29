# Daily Report — terraform-aws-vpc

Date: 2026-07-29

## What was built

A production-style Terraform module that provisions an AWS VPC:

- `versions.tf` / `variables.tf` / `locals.tf` — provider pinning (AWS >= 5.0,
  < 6.0), input variables with plan-time validation, shared tag/NAT-count logic
- `main.tf` — VPC, internet gateway, public/private subnets across AZs,
  per-AZ private route tables, NAT gateways (per-AZ HA mode or single shared
  mode), Elastic IPs, and VPC flow logs to CloudWatch
- `iam.tf` — least-privilege flow-logs role (dedicated trust + inline policy)
  and an SSM instance profile (`AmazonSSMManagedInstanceCore`) for keyless
  access to private EC2 hosts
- `outputs.tf` — subnet/route-table/NAT IDs, NAT public IPs, IAM ARNs
- `examples/complete/main.tf` — a runnable 3-AZ example
- `tests/vpc.tftest.hcl` — 11 test runs using Terraform's native test
  framework with a mocked AWS provider (no credentials needed)
- `README.md` — architecture diagram, design decisions, full input/output
  reference, development instructions

## Test results

- `terraform init -backend=false` — OK (AWS provider 5.x downloaded)
- `terraform fmt -recursive` — clean
- `terraform validate` — Success
- `terraform test` — **11 passed, 0 failed**

Two issues were found and fixed during testing:

1. The mocked `aws_iam_policy_document` data source returned an invalid JSON
   string; fixed by giving the mock a valid default policy document.
2. `map_public_ip_on_launch` was unset on private subnets, so the mock
   generated a random value; fixed by setting it to `false` explicitly in the
   module.

## Git history

- `chore: scaffold project with provider pinning, gitignore, license`
- `feat: VPC module with public/private subnets, NAT gateways, flow logs and IAM roles`
- `test: native terraform test suite with mocked AWS provider (11 runs)`
- `docs: README with architecture and design decisions + daily report`

Local commits only; no remote was created and nothing was pushed.

## Known limitations

- IPv4 only — no IPv6 CIDR/subnet support.
- Tests are plan-only against a mocked provider; no `apply` test against real
  AWS infrastructure (would require credentials and incur cost).
- No support for extra subnet tiers (database/isolated), VPC endpoints, or
  secondary CIDR blocks.
- NAT gateway is the only egress option; NAT instances and egress-only IGW are
  not supported.
- Flow logs go to CloudWatch Logs only (no S3/Kinesis destination).

## Possible next steps

- Add VPC endpoints (S3/DynamoDB gateway endpoints) to cut NAT data costs
- Optional database subnet tier with a dedicated route table
- IPv6 / dual-stack support
- Terratest or an optional `apply`-mode test run in CI against a sandbox AWS
  account
- Publish to the Terraform Registry with a release workflow
