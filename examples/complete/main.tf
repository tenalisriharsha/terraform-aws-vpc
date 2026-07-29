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
  region = "us-east-1"
}

module "vpc" {
  source = "../.."

  name       = "example"
  cidr_block = "10.20.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
  private_subnets = ["10.20.101.0/24", "10.20.102.0/24", "10.20.103.0/24"]

  # One NAT gateway per AZ for production-grade HA.
  # Set single_nat_gateway = true for dev to cut cost (~$32/AZ/month each).
  enable_nat_gateway = true
  single_nat_gateway = false

  tags = {
    Environment = "dev"
    Team        = "platform"
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}
