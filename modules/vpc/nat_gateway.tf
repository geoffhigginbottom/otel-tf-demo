resource "aws_eip" "nat" {
  count  = var.nat_gateway_enabled ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.environment}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  count         = var.nat_gateway_enabled ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = {
    Name = "${var.environment}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.main_vpc_igw]
}

resource "aws_route_table" "public" {
  count  = var.nat_gateway_enabled ? 1 : 0
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_vpc_igw.id
  }

  tags = {
    Name = "${var.environment}-public-route-table"
  }
}

resource "aws_route_table" "private" {
  count  = var.nat_gateway_enabled ? 1 : 0
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }

  tags = {
    Name = "${var.environment}-private-route-table"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.nat_gateway_enabled ? var.subnet_count : 0
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count          = var.nat_gateway_enabled ? var.subnet_count : 0
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private[0].id
}
