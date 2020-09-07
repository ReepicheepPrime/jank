# deploy user
resource "aws_iam_user" "deploy" {
  name = "deploy"
  path = "/${local.project}/"
  tags = local.default_tags
}

# deploy role
resource "aws_iam_role" "deploy" {
  name               = "deploy"
  path               = "/${local.project}/"
  assume_role_policy = data.aws_iam_policy_document.aws_access_assume_role.json
  tags               = local.default_tags
}

data "aws_iam_policy_document" "aws_access_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.deploy.arn]
    }
  }
}

# IAM perms
resource "aws_iam_role_policy" "deploy_iam" {
  name   = "ManageDeployIam"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy_iam.json
}

data "aws_iam_policy_document" "deploy_iam" {
  statement {
    sid = "GetUsers"
    actions = [
      "iam:GetUser",
      "iam:GetUserPolicy",
      "iam:ListAttachedUserPolicies",
      "iam:ListUserPolicies"
    ]
    resources = ["arn:aws:iam::*:user/${local.project}/*"]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:iam::*:user/${local.project}/*"]
    }
  }

  statement {
    sid = "ModifyRoles"
    actions = [
      "iam:*Role",
      "iam:*RolePolicy",
      "iam:*RolePermissionsBoundary",
      "iam:UpdateRoleDescription",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
    ]
    resources = ["arn:aws:iam::*:role/${local.project}/*"]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:iam::*:role/${local.project}/*"]
    }
  }

  statement {
    sid = "ListAll"
    actions = [
      "iam:ListUsers",
      "iam:ListRoles"
    ]
    resources = ["*"]
  }
}

# VPC perms
resource "aws_iam_role_policy" "deploy_vpc" {
  name   = "ManageVPC"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy_vpc.json
}

data "aws_iam_policy_document" "deploy_vpc" {
}

# EC2/ECS perms
resource "aws_iam_role_policy" "deploy_ec2" {
  name   = "ManageEC2"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy_ec2.json
}

data "aws_iam_policy_document" "deploy_ec2" {
  statement {
    id = "Metadata"
    actions = [
      "DescribeAvailabilityZones"
    ]
    resources = ["*"]
  }
}