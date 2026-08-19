resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.Public_CIDRs)
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.Public_CIDRs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = var.AZs[count.index]
  tags = {
    Name = var.Subnet_names[count.index]
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnets[1].id
}



resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_route_table" "internet_route_table" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Internet_Route_Table"
  }
}

resource "aws_route_table_association" "internet_rta" {
  subnet_id      = aws_subnet.public_subnets[0].id
  route_table_id = aws_route_table.internet_route_table.id
}

resource "aws_route_table" "nat_route_table" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    "Name" = "Nat_Route_Table"
  }
}

resource "aws_route_table_association" "nat_application_rta" {
  count          = length(var.Private_CIDRs)
  subnet_id      = aws_subnet.application_subnets[count.index].id
  route_table_id = aws_route_table.nat_route_table.id
}

resource "aws_route_table_association" "nat_rta" {
  subnet_id      = aws_subnet.public_subnets[1].id
  route_table_id = aws_route_table.internet_route_table.id
}

resource "aws_default_route_table" "db_route_table" {
  default_route_table_id = aws_vpc.main_vpc.default_route_table_id
  tags = {
    Name = "Isolated_DB_Route_Table"
  }
}

resource "aws_route_table_association" "db_iso_rta" {
  count          = length(var.DB_CIDRs)
  subnet_id      = aws_subnet.db_subnet[count.index].id
  route_table_id = aws_default_route_table.db_route_table.id
}

resource "aws_subnet" "application_subnets" {
  count             = length(var.Private_CIDRs)
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.Private_CIDRs[count.index]
  availability_zone = var.AZs[count.index]
  tags = {
    Name = "${var.Application_subnet}_${count.index + 1}"
  }
}


resource "aws_subnet" "db_subnet" {
  count             = length(var.DB_CIDRs)
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.DB_CIDRs[count.index]
  availability_zone = var.AZs[count.index]
  tags = {
    Name = "${var.DB_subnet}_${count.index + 1}"
  }
}


