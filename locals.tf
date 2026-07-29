locals {
  # One NAT gateway per AZ for HA, or a single shared one to save cost.
  # When NAT is disabled entirely we create none.
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0

  common_tags = merge(
    {
      Project   = var.name
      ManagedBy = "terraform"
    },
    var.tags,
  )
}
