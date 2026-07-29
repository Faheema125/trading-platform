variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the cluster"
  type        = string
}

variable "secret_arns" {
  description = "List of Secrets Manager ARNs that ECS tasks need access to"
  type        = list(string)
  default     = []
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB, allowed to reach the API on its container port"
  type        = string
}
