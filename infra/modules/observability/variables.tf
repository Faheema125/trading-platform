variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (for CloudWatch metrics)"
  type        = string
}

variable "api_target_group_arn_suffix" {
  description = "API target group ARN suffix (for CloudWatch metrics)"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "api_service_name" {
  description = "API ECS service name"
  type        = string
}

variable "worker_service_name" {
  description = "Worker ECS service name"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS instance identifier"
  type        = string
}

variable "alarm_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = ""
}
