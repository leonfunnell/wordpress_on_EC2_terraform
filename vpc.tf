# Automated VPC creation if vpc_id is not set
resource "aws_vpc" "auto" {
  count                = var.vpc_id == "" ? 1 : 0
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project_name}-auto-vpc"
  }
}

resource "aws_internet_gateway" "auto" {
  count  = var.vpc_id == "" ? 1 : 0
  vpc_id = aws_vpc.auto[0].id
  tags = {
    Name = "${var.project_name}-auto-igw"
  }
}

data "aws_availability_zones" "available" {}

# Create two public subnets in different AZs if we manage the VPC (ALB requires >= 2 subnets)
resource "aws_subnet" "auto" {
  count                   = var.vpc_id == "" ? 2 : 0
  vpc_id                  = aws_vpc.auto[0].id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, count.index + 1) # 10.0.1.0/24, 10.0.2.0/24
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.project_name}-auto-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "auto" {
  count  = var.vpc_id == "" ? 1 : 0
  vpc_id = aws_vpc.auto[0].id
  tags = {
    Name = "${var.project_name}-auto-rt"
  }
}

resource "aws_route" "auto_internet_access" {
  count                  = var.vpc_id == "" ? 1 : 0
  route_table_id         = aws_route_table.auto[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.auto[0].id
}

resource "aws_route_table_association" "auto" {
  count          = var.vpc_id == "" ? length(aws_subnet.auto) : 0
  subnet_id      = aws_subnet.auto[count.index].id
  route_table_id = aws_route_table.auto[0].id
}

# Locals
locals {
  effective_vpc_id    = var.vpc_id != "" ? var.vpc_id : aws_vpc.auto[0].id
  # For the instance we still use a single subnet (first one)
  effective_subnet_id = var.vpc_id != "" ? var.subnet_id : aws_subnet.auto[0].id
  # For ALB we need two subnets; if using existing VPC, expect alb_subnet_ids to be provided
  effective_subnet_ids = var.vpc_id != "" ? (length(var.alb_subnet_ids) > 0 ? var.alb_subnet_ids : (var.subnet_id != "" ? [var.subnet_id] : [])) : [for s in aws_subnet.auto : s.id]
}
