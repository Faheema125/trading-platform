variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs that CI can push to"
  type        = list(string)
}

variable "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  type        = string
  default     = "*"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state"
  type        = string
}

variable "terraform_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
}
