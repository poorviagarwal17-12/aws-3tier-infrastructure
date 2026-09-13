data "aws_caller_identity" "current" {}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
    Tier = "ALB"
  }
}

# App Security Group
resource "aws_security_group" "app" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "App security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-app-sg"
    Tier = "App"
  }
}

# DB Security Group
resource "aws_security_group" "db" {
  name        = "${var.project_name}-${var.environment}-db-sg"
  description = "DB security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-db-sg"
    Tier = "Database"
  }
}

# ALB Security Group Rules
resource "aws_security_group_rule" "alb_http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Inbound HTTP from internet"
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_to_app_egress" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  description              = "Forward HTTP to App SG"
  security_group_id        = aws_security_group.alb.id
}

# App Security Group Rules (Chained to ALB SG and DB SG)
resource "aws_security_group_rule" "app_http_from_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Inbound HTTP from ALB SG only"
  security_group_id        = aws_security_group.app.id
}

resource "aws_security_group_rule" "app_to_db_egress" {
  type                     = "egress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.db.id
  description              = "Outbound to DB SG"
  security_group_id        = aws_security_group.app.id
}

resource "aws_security_group_rule" "app_https_egress" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Outbound HTTPS for SSM and updates"
  security_group_id = aws_security_group.app.id
}

resource "aws_security_group_rule" "app_http_repo_egress" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Outbound HTTP for packages"
  security_group_id = aws_security_group.app.id
}

# DB Security Group Rules (Chained to App SG)
resource "aws_security_group_rule" "db_from_app" {
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  description              = "Inbound DB port from App SG only"
  security_group_id        = aws_security_group.db.id
}

# IAM Role & Policies for EC2
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_app_role" {
  name               = "${var.project_name}-${var.environment}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "s3_read_only" {
  statement {
    sid    = "AllowS3BucketReadOnly"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_read_only" {
  name        = "${var.project_name}-${var.environment}-s3-ro-policy"
  description = "Read-only access to workspace S3 bucket"
  policy      = data.aws_iam_policy_document.s3_read_only.json
}

resource "aws_iam_role_policy_attachment" "s3_read_only" {
  role       = aws_iam_role.ec2_app_role.name
  policy_arn = aws_iam_policy.s3_read_only.arn
}

data "aws_iam_policy_document" "secrets_read" {
  statement {
    sid    = "AllowSecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.environment}-db-credentials*"
    ]
  }
}

resource "aws_iam_policy" "secrets_read" {
  name        = "${var.project_name}-${var.environment}-secrets-ro-policy"
  description = "Read-only access to DB secret"
  policy      = data.aws_iam_policy_document.secrets_read.json
}

resource "aws_iam_role_policy_attachment" "secrets_read" {
  role       = aws_iam_role.ec2_app_role.name
  policy_arn = aws_iam_policy.secrets_read.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.project_name}-${var.environment}-instance-profile"
  role = aws_iam_role.ec2_app_role.name

  tags = {
    Name = "${var.project_name}-${var.environment}-instance-profile"
  }
}
