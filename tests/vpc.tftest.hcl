# Native Terraform tests, run with: terraform test
#
# The AWS provider is mocked, so no credentials or network calls to AWS are
# needed. Every run executes a plan and asserts on the planned resources.

mock_provider "aws" {
  # The mocked data source would otherwise return a random string for `json`,
  # which fails the aws_iam_role schema validation. Give it a valid policy.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name            = "test"
  cidr_block      = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

run "creates_vpc_and_subnets" {
  command = plan

  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block does not match the input."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == true
    error_message = "DNS hostnames should be enabled by default."
  }

  assert {
    condition     = length(aws_subnet.public) == 3
    error_message = "Expected 3 public subnets, one per AZ."
  }

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "Expected 3 private subnets, one per AZ."
  }

  assert {
    condition     = aws_subnet.public[0].cidr_block == "10.0.1.0/24" && aws_subnet.public[0].availability_zone == "us-east-1a"
    error_message = "Public subnet CIDR/AZ mapping is wrong."
  }

  assert {
    condition     = aws_subnet.private[2].cidr_block == "10.0.103.0/24" && aws_subnet.private[2].map_public_ip_on_launch == false
    error_message = "Private subnets must not auto-assign public IPs."
  }
}

run "public_route_table_has_internet_route" {
  command = plan

  assert {
    condition     = aws_route.public_internet.destination_cidr_block == "0.0.0.0/0"
    error_message = "Public route table must route 0.0.0.0/0 to the internet gateway."
  }

  assert {
    condition     = length(aws_route_table_association.public) == 3
    error_message = "Every public subnet must be associated with the public route table."
  }
}

run "nat_gateway_per_az_by_default" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.this) == 3
    error_message = "Expected one NAT gateway per AZ by default (HA mode)."
  }

  assert {
    condition     = length(aws_eip.nat) == 3
    error_message = "Each NAT gateway needs its own Elastic IP."
  }

  assert {
    condition     = length(aws_route.private_nat) == 3
    error_message = "Each private route table must have a default route via NAT."
  }
}

run "single_nat_gateway_mode" {
  command = plan

  variables {
    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "single_nat_gateway = true should create exactly one NAT gateway."
  }

  assert {
    condition     = length(aws_route.private_nat) == 3
    error_message = "Private subnets should still route through the shared NAT gateway."
  }
}

run "nat_can_be_disabled" {
  command = plan

  variables {
    enable_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0 && length(aws_eip.nat) == 0
    error_message = "enable_nat_gateway = false must not create NAT gateways or EIPs."
  }

  assert {
    condition     = length(aws_route.private_nat) == 0
    error_message = "No NAT routes should exist when NAT is disabled."
  }
}

run "flow_logs_enabled_by_default" {
  command = plan

  assert {
    condition     = length(aws_flow_log.this) == 1
    error_message = "A VPC flow log should be created by default."
  }

  assert {
    condition     = aws_flow_log.this[0].traffic_type == "ALL"
    error_message = "Flow logs should capture ALL traffic."
  }

  assert {
    condition     = length(aws_iam_role.flow_logs) == 1 && length(aws_iam_role_policy.flow_logs) == 1
    error_message = "Flow logs need an IAM role with an inline write policy."
  }
}

run "flow_logs_can_be_disabled" {
  command = plan

  variables {
    enable_flow_logs = false
  }

  assert {
    condition     = length(aws_flow_log.this) == 0 && length(aws_cloudwatch_log_group.flow_logs) == 0
    error_message = "enable_flow_logs = false must skip the flow log and its log group."
  }

  assert {
    condition     = length(aws_iam_role.flow_logs) == 0
    error_message = "The flow logs IAM role should not exist when flow logs are disabled."
  }
}

run "ssm_instance_role_always_created" {
  command = plan

  assert {
    condition     = aws_iam_instance_profile.ssm_instance.name == "test-ssm-instance"
    error_message = "SSM instance profile name should follow the <name>-ssm-instance convention."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.ssm_core.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "SSM role must attach the AmazonSSMManagedInstanceCore managed policy."
  }
}

run "tags_are_propagated" {
  command = plan

  variables {
    tags = { Environment = "test", Owner = "platform" }
  }

  assert {
    condition     = aws_vpc.this.tags["Environment"] == "test" && aws_vpc.this.tags["ManagedBy"] == "terraform"
    error_message = "Custom and common tags must be merged onto the VPC."
  }

  assert {
    condition     = aws_subnet.private[0].tags["Tier"] == "private"
    error_message = "Private subnets must carry a Tier=private tag."
  }
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    cidr_block = "not-a-cidr"
  }

  expect_failures = [
    var.cidr_block,
  ]
}

run "rejects_too_many_azs" {
  command = plan

  variables {
    azs = ["a", "b", "c", "d", "e", "f", "g"]
  }

  expect_failures = [
    var.azs,
  ]
}

run "rejects_fewer_public_subnets_than_azs" {
  command = plan

  variables {
    public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  }

  expect_failures = [
    aws_vpc.this,
  ]
}

run "rejects_more_private_subnets_than_azs" {
  command = plan

  variables {
    private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24", "10.0.104.0/24"]
  }

  expect_failures = [
    aws_vpc.this,
  ]
}

run "rejects_fewer_private_subnets_than_azs" {
  command = plan

  variables {
    private_subnets = ["10.0.101.0/24"]
  }

  expect_failures = [
    aws_vpc.this,
  ]
}
