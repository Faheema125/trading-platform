variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "name" {
  description = "Service name (e.g., api, worker, nats)"
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "image" {
  description = "Docker image URI"
  type        = string
}

variable "cpu" {
  description = "CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of tasks to run"
  type        = number
  default     = 1
}

variable "subnet_ids" {
  description = "Subnet IDs for task placement"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for tasks"
  type        = list(string)
}

variable "execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN (permissions for the running container)"
  type        = string
  default     = null
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# ─────────────────────────────────────────────────────────────
# Container Configuration
# ─────────────────────────────────────────────────────────────

variable "command" {
  description = "Container command override"
  type        = list(string)
  default     = null
}

variable "port_mappings" {
  description = "List of container ports to expose"
  type        = list(number)
  default     = []
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "secrets" {
  description = "Secrets from Secrets Manager/SSM to inject"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "health_check" {
  description = "Container health check configuration"
  type = object({
    command     = list(string)
    interval    = number
    timeout     = number
    retries     = number
    startPeriod = number
  })
  default = null
}

variable "readonly_root_filesystem" {
  description = "Whether the container has a read-only root filesystem"
  type        = bool
  default     = true
}

# ─────────────────────────────────────────────────────────────
# Load Balancer (optional)
# ─────────────────────────────────────────────────────────────

variable "target_group_arn" {
  description = "ALB target group ARN (set to attach service to load balancer)"
  type        = string
  default     = null
}

# ─────────────────────────────────────────────────────────────
# Service Discovery (optional)
# ─────────────────────────────────────────────────────────────

variable "enable_service_discovery" {
  description = "Register this service with Cloud Map for DNS-based discovery"
  type        = bool
  default     = false
}

variable "service_discovery_namespace_id" {
  description = "Cloud Map namespace ID for service discovery"
  type        = string
  default     = null
}

# ─────────────────────────────────────────────────────────────
# Deployment Configuration
# ─────────────────────────────────────────────────────────────

variable "enable_circuit_breaker" {
  description = "Enable deployment circuit breaker with automatic rollback"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}
