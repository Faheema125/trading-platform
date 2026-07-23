# ─────────────────────────────────────────────────────────────
# Random password for the database
# ─────────────────────────────────────────────────────────────

resource "random_password" "db_password" {
  length  = 24
  special = false # avoid special chars that cause issues in connection strings
}

# ─────────────────────────────────────────────────────────────
# Store password in Secrets Manager
# ─────────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.environment}/trading/db-password"
  description             = "RDS master password for ${var.environment}"
  recovery_window_in_days = 0 # allow immediate deletion in dev

  tags = {
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

# ─────────────────────────────────────────────────────────────
# DB Subnet Group (places RDS in private subnets)
# ─────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────────────────────────
# Security Group (only ECS tasks can reach port 5432)
# ─────────────────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${var.environment}-rds-sg"
  description = "Allow Postgres access from ECS tasks"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-rds-sg"
    Environment = var.environment
  }
}

resource "aws_security_group_rule" "rds_ingress" {
  count = length(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.rds.id
}

# ─────────────────────────────────────────────────────────────
# RDS Postgres Instance
# ─────────────────────────────────────────────────────────────

resource "aws_db_instance" "main" {
  identifier = "${var.environment}-trading-db"

  engine         = "postgres"
  engine_version = "15"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = var.multi_az
  publicly_accessible = false
  storage_encrypted   = true

  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.environment == "dev" ? true : false
  final_snapshot_identifier = var.environment == "dev" ? null : "${var.environment}-trading-db-final"

  tags = {
    Name        = "${var.environment}-trading-db"
    Environment = var.environment
  }
}
