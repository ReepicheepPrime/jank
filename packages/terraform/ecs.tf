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
resource "aws_service_discovery_private_dns_namespace" "ecs" {
  name = "${local.cluster_name}.${local.project}.local"
  vpc  = aws_vpc.ecs.id
}

resource "aws_apigatewayv2_vpc_link" "ecs" {
  name               = "ecs-${local.cluster_name}"
  security_group_ids = [aws_security_group.ecs.id]
  subnet_ids         = [for subnet in aws_subnet.ecs : subnet.id]
  tags               = local.default_tags
}
