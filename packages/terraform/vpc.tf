resource "aws_vpc" "ecs" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.default_tags, {
    Name = "ECS"
  })
}

resource "aws_subnet" "ecs" {
  count = length(data.aws_availability_zones.available.names)

  vpc_id                  = aws_vpc.ecs.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = local.default_tags
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_main_route_table_association" "ecs" {
  vpc_id         = aws_vpc.ecs.id
  route_table_id = aws_route_table.ecs.id
}

resource "aws_route_table" "ecs" {
  vpc_id = aws_vpc.ecs.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ecs.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.ecs.id
  }

  tags = local.default_tags
}

resource "aws_internet_gateway" "ecs" {
  vpc_id = aws_vpc.ecs.id
  tags   = local.default_tags
}

resource "aws_egress_only_internet_gateway" "ecs" {
  vpc_id = aws_vpc.ecs.id
  tags   = local.default_tags
}

resource "aws_route_table_association" "ecs" {
  for_each       = toset([for subnet in aws_subnet.ecs : subnet.id])
  route_table_id = aws_route_table.ecs.id
  subnet_id      = each.value
}

resource "aws_security_group" "ecs" {
  name        = "${local.project}-ecs"
  description = "Allow outbound only"
  vpc_id      = aws_vpc.ecs.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.default_tags
}