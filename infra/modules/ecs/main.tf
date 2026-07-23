# ─────────────────────────────────────────────────────────────
# ECS Cluster
# ─────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-trading-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Environment = var.environment
  }
}

# ─────────────────────────────────────────────────────────────
# CloudWatch Log Groups
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.environment}/api"
  retention_in_days = 14

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${var.environment}/worker"
  retention_in_days = 14

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "nats" {
  name              = "/ecs/${var.environment}/nats"
  retention_in_days = 14

  tags = { Environment = var.environment }
}

# ─────────────────────────────────────────────────────────────
# Security Groups
# ─────────────────────────────────────────────────────────────

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.environment}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  # Allow all outbound (to reach RDS, NATS, NAT Gateway)
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

# Allow ALB to reach API on port 8080
resource "aws_security_group_rule" "api_ingress" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Will be restricted to ALB SG in ALB module
  security_group_id = aws_security_group.ecs_tasks.id
}

# Allow tasks to talk to NATS on port 4222
resource "aws_security_group_rule" "nats_ingress" {
  type                     = "ingress"
  from_port                = 4222
  to_port                  = 4222
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.ecs_tasks.id
}

# ─────────────────────────────────────────────────────────────
# NATS Service (runs as ECS service in private subnet)
# ─────────────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "nats" {
  family                   = "${var.environment}-nats"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.nats_cpu
  memory                   = var.nats_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "nats"
    image     = var.nats_image
    essential = true
    command   = ["--jetstream", "--store_dir", "/data", "--http_port", "8222"]

    portMappings = [
      { containerPort = 4222, protocol = "tcp" },
      { containerPort = 8222, protocol = "tcp" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.nats.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "nats"
      }
    }
  }])

  tags = { Environment = var.environment }
}

resource "aws_ecs_service" "nats" {
  name            = "${var.environment}-nats"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nats.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  # Service discovery so API/Worker can find NATS by DNS name
  service_registries {
    registry_arn = aws_service_discovery_service.nats.arn
  }

  tags = { Environment = var.environment }
}

# ─────────────────────────────────────────────────────────────
# Service Discovery (Cloud Map) for NATS
# ─────────────────────────────────────────────────────────────

resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "${var.environment}.trading.local"
  vpc  = var.vpc_id

  tags = { Environment = var.environment }
}

resource "aws_service_discovery_service" "nats" {
  name = "nats"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# ─────────────────────────────────────────────────────────────
# API Service
# ─────────────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.environment}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.api_cpu
  memory                   = var.api_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "api"
    image     = var.api_image
    essential = true

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    environment = [
      { name = "PORT", value = "8080" },
      { name = "NATS_URL", value = "nats://nats.${var.environment}.trading.local:4222" },
      { name = "DATABASE_URL", value = "postgres://${var.database_username}:PLACEHOLDER@${var.database_host}/${var.database_name}?sslmode=require" }
    ]

    secrets = [{
      name      = "DB_PASSWORD"
      valueFrom = var.db_password_secret_arn
    }]

    readonlyRootFilesystem = true

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.api.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "api"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "wget --spider -q http://localhost:8080/health || exit 1"]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
  }])

  tags = { Environment = var.environment }
}

resource "aws_ecs_service" "api" {
  name            = "${var.environment}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "api"
    container_port   = 8080
  }

  # Zero-downtime deploys with automatic rollback
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  tags = { Environment = var.environment }
}

# ─────────────────────────────────────────────────────────────
# Worker Service
# ─────────────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.environment}-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "worker"
    image     = var.worker_image
    essential = true

    environment = [
      { name = "NATS_URL", value = "nats://nats.${var.environment}.trading.local:4222" },
      { name = "DATABASE_URL", value = "postgres://${var.database_username}:PLACEHOLDER@${var.database_host}/${var.database_name}?sslmode=require" }
    ]

    secrets = [{
      name      = "DB_PASSWORD"
      valueFrom = var.db_password_secret_arn
    }]

    readonlyRootFilesystem = true

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.worker.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "worker"
      }
    }
  }])

  tags = { Environment = var.environment }
}

resource "aws_ecs_service" "worker" {
  name            = "${var.environment}-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.worker_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  # Zero-downtime deploys with automatic rollback
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = { Environment = var.environment }
}
