output "vpc_id" {
    value = aws_vpc.main_vpc.id
}

output "private_subnet_ids" {
    value = aws_subnet.private_subnets.*.id
}

output "public_subnet_ids" {
    value = aws_subnet.public_subnets.*.id
}

output "route_table_ids" {
  value = var.nat_gateway_enabled ? aws_route_table.public[0].id : aws_route.main_vpc_route[0].route_table_id
}