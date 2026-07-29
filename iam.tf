# -----------------------------------------------------------------------------
# IAM roles
#
# Two narrowly-scoped roles, following least privilege:
#   1. flow_logs      - lets the VPC Flow Logs service write to CloudWatch Logs.
#   2. ssm_instance   - instance profile for EC2 hosts in the private subnets,
#                       so they are reachable via AWS Systems Manager Session
#                       Manager without SSH keys or public IPs.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "flow_logs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name               = "${var.name}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "flow_logs_write" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name   = "${var.name}-vpc-flow-logs-write"
  role   = aws_iam_role.flow_logs[0].id
  policy = data.aws_iam_policy_document.flow_logs_write.json
}

resource "aws_iam_role" "ssm_instance" {
  name = "${var.name}-ssm-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance" {
  name = "${var.name}-ssm-instance"
  role = aws_iam_role.ssm_instance.name

  tags = local.common_tags
}
