variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "api_image" {
  description = "Docker image URI for the API service"
  type        = string
}

variable "worker_image" {
  description = "Docker image URI for the Worker service"
  type        = string
}

variable "nats_image" {
  description = "Docker image for NATS"
  type        = string
  default     = "nats:2.10-alpine"
}

variable "api_cpu" {
  description = "CPU units for API task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "api_memory" {
  description = "Memory in MB for API task"
  type        = number
  default     = 512
}

variable "worker_cpu" {
  description = "CPU units for Worker task"
  type        = number
  default     = 256
}

variable "worker_memory" {
  description = "Memory in MB for Worker task"
  type        = number
  default     = 512
}

variable "nats_cpu" {
  description = "CPU units for NATS task"
  type        = number
  default     = 256
}

variable "nats_memory" {
  description = "Memory in MB for NATS task"
  type        = number
  default     = 512
}

variable "api_desired_count" {
  description = "Number of API tasks to run"
  type        = number
  default     = 1
}

variable "worker_desired_count" {
  description = "Number of Worker tasks to run"
  type        = number
  default     = 1
}

variable "database_url_arn" {
  description = "ARN of the Secrets Manager secret containing DATABASE_URL"
  type        = string
}

variable "db_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the DB password"
  type        = string
}

variable "database_host" {
  description = "RDS endpoint hostname"
  type        = string
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "database_username" {
  description = "Database username"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN for the API service"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
