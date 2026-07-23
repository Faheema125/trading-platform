# ─────────────────────────────────────────────────────────────
# ECS Task Execution Role
# (Used by ECS agent to pull images, push logs, read secrets)
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

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_base" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow reading secrets from Secrets Manager
resource "aws_iam_policy" "ecs_secrets" {
  name = "${var.environment}-ecs-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = [
        var.db_password_secret_arn
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_secrets" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = aws_iam_policy.ecs_secrets.arn
}

# ─────────────────────────────────────────────────────────────
# ECS Task Role
# (Used by the running container — least privilege)
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

  tags = {
    Environment = var.environment
  }
}

# Task role has no additional policies — least privilege.
# Add permissions here only if the app needs to call AWS APIs directly.
