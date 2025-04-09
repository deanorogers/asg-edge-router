resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  tags                 = local.common_tags
}

locals {
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

/***************************************
** these are public subnets, having an IGW
***************************************/
resource "aws_subnet" "subnet1" {
  cidr_block              = var.vpc_subnets_cidr_block[0]
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = var.map_public_ip_on_launch
  availability_zone       = local.availability_zones[0]
  tags                    = local.common_tags
}

resource "aws_subnet" "subnet2" {
  cidr_block              = var.vpc_subnets_cidr_block[1]
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = var.map_public_ip_on_launch
  availability_zone       = local.availability_zones[1]
  tags                    = local.common_tags
}

resource "aws_subnet" "subnet3" {
  cidr_block              = var.vpc_subnets_cidr_block[2]
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = var.map_public_ip_on_launch
  availability_zone       = local.availability_zones[2]
  tags                    = local.common_tags
}

# ROUTING #

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}

resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = local.common_tags
}

resource "aws_route_table_association" "rta-subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rtb.id
}

resource "aws_route_table_association" "rta-subnet2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rtb.id
}

resource "aws_route_table_association" "rta-subnet3" {
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.rtb.id
}