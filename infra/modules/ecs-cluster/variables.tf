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
