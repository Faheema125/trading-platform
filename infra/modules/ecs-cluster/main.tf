# ─────────────────────────────────────────────────────────────
# ECS Cluster Module
# Shared infrastructure: cluster, IAM roles, security groups,
# service discovery namespace
# ─────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────
# Service-Linked Role
# ─────────────────────────────────────────────────────────────

resource "aws_iam_service_linked_role" "ecs" {
  aws_service_name = "ecs.amazonaws.com"

  lifecycle {
    ignore_changes = [description]
  }
}

# ─────────────────────────────────────────────────────────────
# ECS Cluster
# ─────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-trading-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  depends_on = [aws_iam_service_linked_role.ecs]

  tags = {
    Environment = var.environment
  }
}

# ─────────────────────────────────────────────────────────────
# Security Group (shared across all ECS services)
# ─────────────────────────────────────────────────────────────

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.environment}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-ecs-tasks-sg"
    Environment = var.environment
  }
}

# ALB → API traffic on port 8080
resource "aws_security_group_rule" "api_ingress" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_tasks.id
}

# Inter-task NATS traffic on port 4222
resource "aws_security_group_rule" "nats_ingress" {
  type                     = "ingress"
  from_port                = 4222
  to_port                  = 4222
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.ecs_tasks.id
}

# ─────────────────────────────────────────────────────────────
# Service Discovery Namespace
# ─────────────────────────────────────────────────────────────

resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "${var.environment}.trading.local"
  vpc  = var.vpc_id

  tags = { Environment = var.environment }
}

# ─────────────────────────────────────────────────────────────
# IAM — Task Execution Role (pull images, push logs, read secrets)
# ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "ecs_execution" {
  name = "${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = { Environment = var.environment }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_base" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_secrets" {
  name = "${var.environment}-ecs-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.secret_arns
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_secrets" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = aws_iam_policy.ecs_secrets.arn
}

# ─────────────────────────────────────────────────────────────
# IAM — Task Role (used by running containers)
# ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "ecs_task" {
  name = "${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = { Environment = var.environment }
}
