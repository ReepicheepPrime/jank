# deploy user
resource "aws_iam_user" "deploy" {
  name = "deploy"
  path = var.project
}

# deploy role
resource "aws_iam_role" "deploy" {
  name               = "deploy"
  assume_role_policy = data.aws_iam_policy_document.aws_access_assume_role.json
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

# deploy perms
resource "aws_iam_role_policy" "deploy_iam" {
  name   = "ManageDeployIam"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy_iam.json
}

data "aws_iam_policy_document" "deploy_iam" {
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
    resources = ["arn:aws:iam::*:role/deploy-*"]
    condition {
      test     = "ArnNotEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:iam::*:role/deploy"]
    }
  }

  statement {
    sid = "ListAll"
    actions = [
      "iam:ListRoles"
    ]
    resources = ["*"]
  }
}
