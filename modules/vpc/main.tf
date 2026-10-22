data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

resource "aws_subnet" "subnets" {
  for_each = {
    public_1 = {
      cidr = "10.0.1.0/24"
      az   = data.aws_availability_zones.available.names[0]
    }
    public_2 = {
      cidr = "10.0.0.0/24"
      az   = data.aws_availability_zones.available.names[1]
    }
    private_app_1 = {
      cidr = "10.0.2.0/24"
      az   = data.aws_availability_zones.available.names[0]
    }
    private_db_1 = {
      cidr = "10.0.3.0/24"
      az   = data.aws_availability_zones.available.names[0]
    }
    private_db_2 = {
      cidr = "10.0.4.0/24"
      az   = data.aws_availability_zones.available.names[1]
    }
  }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "wordpress-${replace(each.key, "_", "-")}"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "wordpress-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "wordpress-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = toset(["public_1", "public_2"])

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  lifecycle {
    precondition {
      condition     = length(data.aws_availability_zones.available.names) >= 2
      error_message = "This lab requires at least two available standard Availability Zones."
    }
  }

  tags = {
    Name = var.vpc_name
  }
}

# Only the application subnet gets outbound internet access.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "wordpress-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnets["public_1"].id
  depends_on    = [aws_internet_gateway.this, aws_route_table_association.public]

  tags = { Name = "wordpress-nat" }
}

resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = { Name = "wordpress-private-app-rt" }
}

resource "aws_route_table_association" "private_app" {
  subnet_id      = aws_subnet.subnets["private_app_1"].id
  route_table_id = aws_route_table.private_app.id
}
