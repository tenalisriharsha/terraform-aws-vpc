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

  # Inclusive [start, end] integer bounds for a CIDR, used to check that
  # subnets fall inside the VPC range and don't overlap each other.
  # cidrhost(cidr, 0) normalizes to the network address so the math below
  # doesn't depend on the caller passing an already-aligned CIDR.
  vpc_cidr_start = sum([for i, octet in split(".", cidrhost(var.cidr_block, 0)) : tonumber(octet) * pow(256, 3 - i)])
  vpc_cidr_end   = local.vpc_cidr_start + pow(2, 32 - tonumber(split("/", var.cidr_block)[1])) - 1

  subnet_entries = concat(
    [for i, cidr in var.public_subnets : { key = "public_subnets[${i}] (${cidr})", cidr = cidr }],
    [for i, cidr in var.private_subnets : { key = "private_subnets[${i}] (${cidr})", cidr = cidr }],
  )

  subnet_bounds = [for e in local.subnet_entries : merge(e, {
    start = sum([for i, octet in split(".", cidrhost(e.cidr, 0)) : tonumber(octet) * pow(256, 3 - i)])
    end   = sum([for i, octet in split(".", cidrhost(e.cidr, 0)) : tonumber(octet) * pow(256, 3 - i)]) + pow(2, 32 - tonumber(split("/", e.cidr)[1])) - 1
  })]

  subnets_outside_vpc_cidr = [
    for b in local.subnet_bounds : b.key
    if b.start < local.vpc_cidr_start || b.end > local.vpc_cidr_end
  ]

  overlapping_subnet_pairs = [
    for pair in setproduct(range(length(local.subnet_bounds)), range(length(local.subnet_bounds))) : "${local.subnet_bounds[pair[0]].key} and ${local.subnet_bounds[pair[1]].key}"
    if pair[0] < pair[1] && local.subnet_bounds[pair[0]].start <= local.subnet_bounds[pair[1]].end && local.subnet_bounds[pair[1]].start <= local.subnet_bounds[pair[0]].end
  ]
}
