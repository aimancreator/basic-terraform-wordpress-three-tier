
resource "aws_vpc_endpoint" "ssm" {
  for_each = toset(["ssm", "ssmmessages", "secretsmanager"])

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.subnet_id]
  security_group_ids  = [var.security_group_id]
  private_dns_enabled = true

  tags = {
    Name = "wordpress-${each.key}-endpoint"
  }
}
