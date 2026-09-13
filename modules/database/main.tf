resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_string" "secret_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-${var.environment}-db-credentials-${random_string.secret_suffix.result}"
  description             = "Database credentials for ${var.environment}"
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    engine   = "mysql"
    username = var.db_username
    password = random_password.db_password.result
    database = var.db_name
    port     = 3306
  })
}

resource "aws_db_instance" "this" {
  identifier                 = "${var.project_name}-${var.environment}-mysql"
  engine                     = "mysql"
  engine_version             = "8.0"
  instance_class             = var.db_instance_class
  allocated_storage          = 20
  max_allocated_storage      = 20
  storage_type               = "gp2"
  db_name                    = var.db_name
  username                   = var.db_username
  password                   = random_password.db_password.result
  db_subnet_group_name       = var.db_subnet_group_name
  vpc_security_group_ids     = [var.db_security_group_id]
  multi_az                   = false
  publicly_accessible        = false
  skip_final_snapshot        = true
  deletion_protection        = var.deletion_protection
  apply_immediately          = true
  auto_minor_version_upgrade = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-mysql"
    Environment = var.environment
    Tier        = "Database"
  }
}
