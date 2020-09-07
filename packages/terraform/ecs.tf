locals {
  api_cluster_name = "api"
}

# EC2
data "aws_ami" "amazon_linux_ecs" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

resource "aws_launch_template" "ecs_api" {
  name_prefix   = "ecs-api"
  instance_type = "t3a.micro"
  image_id      = data.aws_ami.amazon_linux_ecs.id

  user_data = base64encode(templatefile("ecs-bootstrap.sh.tpl", {
    cluster = local.api_cluster_name
  }))

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs.arn
  }

  monitoring {
    enabled = true
  }

  # ebs {
  #   delete_on_termination = true
  #   volume_type = "gp2"
  #   volume_size = 30
  # }

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [
      aws_security_group.ecs_api.id
    ]
  }

  instance_market_options {
    market_type = "spot"
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags = local.default_tags
}

resource "aws_iam_instance_profile" "ecs" {
  name = "ecs"
  role = aws_iam_role.ecs_instance.name
}

resource "aws_iam_role" "ecs_instance" {
  name               = "ecs-instance"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_security_group" "ecs_api" {
  name        = "ecs-api"
  description = "Allow outbound only"
  vpc_id      = aws_vpc.ecs_api.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.default_tags
}

# Spot fleet
resource "aws_spot_fleet_request" "ecs_api" {
  spot_price          = "0.03"
  fleet_type          = "maintain"
  allocation_strategy = "diversified"
  iam_fleet_role      = aws_iam_role.ecs_spot_fleet.arn
  target_capacity     = var.ecs_capacity


  launch_template_config {
    launch_template_specification {
      id      = aws_launch_template.ecs_api.id
      version = aws_launch_template.ecs_api.latest_version
    }

    dynamic "overrides" {
      for_each = aws_subnet.ecs_api
      content {
        subnet_id = overrides.value.id
      }
    }
  }

  tags = local.default_tags
}

resource "aws_iam_role" "ecs_spot_fleet" {
  name               = "ecs-spot-fleet"
  assume_role_policy = data.aws_iam_policy_document.assume_spot_fleet.json
}

resource "aws_iam_role_policy_attachment" "ecs_spot_fleet" {
  role       = aws_iam_role.ecs_spot_fleet.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

data "aws_iam_policy_document" "assume_spot_fleet" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["spotfleet.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# VPC
resource "aws_vpc" "ecs_api" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.default_tags, {
    Name = "API (ECS)"
  })
}

resource "aws_subnet" "ecs_api" {
  count = length(data.aws_availability_zones.available.names)

  vpc_id                  = aws_vpc.ecs_api.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = local.default_tags
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_main_route_table_association" "ecs_api" {
  vpc_id         = aws_vpc.ecs_api.id
  route_table_id = aws_route_table.ecs_api.id
}

resource "aws_route_table" "ecs_api" {
  vpc_id = aws_vpc.ecs_api.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ecs_api.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.ecs_api.id
  }

  tags = local.default_tags
}

resource "aws_internet_gateway" "ecs_api" {
  vpc_id = aws_vpc.ecs_api.id
  tags   = local.default_tags
}

resource "aws_egress_only_internet_gateway" "ecs_api" {
  vpc_id = aws_vpc.ecs_api.id
  tags   = local.default_tags
}

resource "aws_route_table_association" "ecs_api" {
  for_each       = toset([for subnet in aws_subnet.ecs_api : subnet.id])
  route_table_id = aws_route_table.ecs_api.id
  subnet_id      = each.value
}

# ECS
resource "aws_ecs_cluster" "api" {
  name = local.api_cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.default_tags
}

# Service Map
resource "aws_service_discovery_private_dns_namespace" "ecs_api" {
  name = "${local.api_cluster_name}.${local.project}.local"
  vpc  = aws_vpc.ecs_api.id
}

resource "aws_apigatewayv2_vpc_link" "ecs_api" {
  name               = local.api_cluster_name
  security_group_ids = [aws_security_group.ecs_api.id]
  subnet_ids         = [for subnet in aws_subnet.ecs_api : subnet.id]
  tags               = local.default_tags
}
