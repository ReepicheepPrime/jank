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

resource "aws_launch_template" "ecs" {
  name_prefix   = "${local.project}-ecs"
  instance_type = "t3a.micro"
  image_id      = data.aws_ami.amazon_linux_ecs.id

  user_data = base64encode(templatefile("ecs-bootstrap.sh.tpl", {
    cluster = local.cluster_name
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
      aws_security_group.ecs.id
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
  name = "${local.project}-ecs"
  role = aws_iam_role.ecs_instance.name
}

resource "aws_iam_role" "ecs_instance" {
  name               = "${local.project}-ecs-instance"
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

# Spot fleet
resource "aws_spot_fleet_request" "ecs" {
  spot_price          = "0.03"
  fleet_type          = "maintain"
  allocation_strategy = "diversified"
  iam_fleet_role      = aws_iam_role.ecs_spot_fleet.arn
  target_capacity     = var.ecs_capacity


  launch_template_config {
    launch_template_specification {
      id      = aws_launch_template.ecs.id
      version = aws_launch_template.ecs.latest_version
    }

    dynamic "overrides" {
      for_each = aws_subnet.ecs
      content {
        subnet_id = overrides.value.id
      }
    }
  }

  tags = local.default_tags
}

resource "aws_iam_role" "ecs_spot_fleet" {
  name = "ecs-spot-fleet"
  path = "/${local.project}/"
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