variable "name" {
  description = "Name prefix applied to all resources (e.g. \"prod\")."
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 32
    error_message = "name must be between 1 and 32 characters."
  }

  validation {
    condition     = can(regex("^[\\w+=,.@-]+$", var.name))
    error_message = "name must match [\\w+=,.@-] (letters, digits, underscores, and the characters +=,.@-) so it is valid in downstream IAM role and CloudWatch Logs group names."
  }
}

variable "cidr_block" {
  description = "Primary IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 CIDR, e.g. \"10.0.0.0/16\"."
  }
}

variable "azs" {
  description = "List of availability zones to spread subnets across. Length must match the subnet lists."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 1 && length(var.azs) <= 6
    error_message = "Provide between 1 and 6 availability zones."
  }
}

variable "public_subnets" {
  description = "List of CIDR blocks for public subnets, one per AZ."
  type        = list(string)
}

variable "private_subnets" {
  description = "List of CIDR blocks for private subnets, one per AZ."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateways so private subnets can reach the internet."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT gateway (cheaper, no AZ redundancy) instead of one per AZ."
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS resolution in the VPC."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Publish VPC flow logs to CloudWatch Logs (uses the IAM role in iam.tf)."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "CloudWatch Logs retention period for VPC flow logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_logs_retention_days)
    error_message = "flow_logs_retention_days must be one of the values accepted by CloudWatch Logs: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, or 3653."
  }
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
