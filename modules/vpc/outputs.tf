output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_app_subnet_id" {
  value      = aws_subnet.subnets["private_app_1"].id
  depends_on = [aws_route_table_association.private_app]
}

output "db_subnet_ids" {
  value = [
    aws_subnet.subnets["private_db_1"].id,
    aws_subnet.subnets["private_db_2"].id
  ]
}

output "public_subnet_ids" {
  value = [
    aws_subnet.subnets["public_1"].id,
    aws_subnet.subnets["public_2"].id
  ]
}
