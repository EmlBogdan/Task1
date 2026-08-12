terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
}

provider "aws" {}

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/24"
}

resource "aws_subnet" "public_subnets" {
  count             = 2
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.Public_CIDRs[count.index] # 10.3.0.0/16 and 10.4.0.0/16
  availability_zone = var.AZs[count.index]
  tags = {
    Name = var.Subnet_names[count.index]
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public_Route_Table"
  }
}

resource "aws_route_table_association" "public_rta" {
  count          = 2
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_subnet" "application_subnets" {
  count             = 2
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.Private_CIDRs[count.index] # 10.3.0.0/16 and 10.4.0.0/16
  availability_zone = var.AZs[count.index]
  tags = {
    Name = "${var.Subnet_names[2]}_${count.index + 1}"
  }
}


resource "aws_subnet" "db_subnet" {
  count             = 2
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.Private_CIDRs[count.index + 2]
  availability_zone = var.AZs[count.index]
  tags = {
    Name = "${var.Subnet_names[3]}_${count.index + 1}"
  }
}


