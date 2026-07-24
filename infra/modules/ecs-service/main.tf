# ─────────────────────────────────────────────────────────────
# ECS Service Module (Reusable)
# Deploys a single Fargate service with task definition,
# log group, optional load balancer, and optional service discovery.
# ─────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────
# CloudWatch Log Group
# ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.environment}/${var.name}"
  retention_in_days = var.log_retention_days

  tags = { Environment = var.environment }
}

# ─────────────────────────────────────────────────────────────
# Service Discovery (optional)
# ─────────────────────────────────────────────────────────────

resource "aws_service_discovery_service" "this" {
  count = var.enable_service_discovery ? 1 : 0

  name = var.name

  dns_config {
    namespace_id = var.service_discovery_namespace_id

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
# Task Definition
# ─────────────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.environment}-${var.name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name      = var.name
    image     = var.image
    essential = true
    command   = var.command

    portMappings = [for port in var.port_mappings : {
      containerPort = port
      protocol      = "tcp"
    }]

    environment = var.environment_variables
    secrets     = var.secrets

    readonlyRootFilesystem = var.readonly_root_filesystem

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.this.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = var.name
      }
    }

    healthCheck = var.health_check
  }])

  tags = { Environment = var.environment }
}

# ─────────────────────────────────────────────────────────────
# ECS Service
# ─────────────────────────────────────────────────────────────

resource "aws_ecs_service" "this" {
  name            = "${var.environment}-${var.name}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.name
      container_port   = var.port_mappings[0]
    }
  }

  dynamic "service_registries" {
    for_each = var.enable_service_discovery ? [1] : []
    content {
      registry_arn = aws_service_discovery_service.this[0].arn
    }
  }

  dynamic "deployment_circuit_breaker" {
    for_each = var.enable_circuit_breaker ? [1] : []
    content {
      enable   = true
      rollback = true
    }
  }

  deployment_minimum_healthy_percent = var.enable_circuit_breaker ? 100 : 0
  deployment_maximum_percent         = var.enable_circuit_breaker ? 200 : 100

  tags = { Environment = var.environment }
}
