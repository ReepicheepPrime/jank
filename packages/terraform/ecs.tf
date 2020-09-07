locals {
  cluster_name = "${local.project}-default"
}

resource "aws_ecs_cluster" "default" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.default_tags
}

# Service Map
resource "aws_service_discovery_private_dns_namespace" "ecs_api" {
  name = "${local.cluster_name}.${local.project}.local"
  vpc  = aws_vpc.ecs_api.id
}

resource "aws_apigatewayv2_vpc_link" "ecs_api" {
  name               = "ecs-${local.cluster_name}"
  security_group_ids = [aws_security_group.ecs_api.id]
  subnet_ids         = [for subnet in aws_subnet.ecs_api : subnet.id]
  tags               = local.default_tags
}
