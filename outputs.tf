output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, in AZ order."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, in AZ order."
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  description = "ID of the shared public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of the per-AZ private route tables."
  value       = aws_route_table.private[*].id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways (empty when NAT is disabled)."
  value       = aws_nat_gateway.this[*].id
}

output "nat_public_ips" {
  description = "Elastic IPs assigned to the NAT gateways (empty when NAT is disabled)."
  value       = aws_eip.nat[*].public_ip
}

output "flow_logs_role_arn" {
  description = "ARN of the IAM role used by VPC Flow Logs (null when flow logs are disabled)."
  value       = try(aws_iam_role.flow_logs[0].arn, null)
}

output "ssm_instance_profile_name" {
  description = "Name of the instance profile that grants SSM Session Manager access."
  value       = aws_iam_instance_profile.ssm_instance.name
}
