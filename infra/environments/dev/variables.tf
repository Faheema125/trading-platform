variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "api_image" {
  description = "ECR image URI for the API"
  type        = string
  default     = "424999960857.dkr.ecr.us-east-1.amazonaws.com/trading-platform/api:latest"
}

variable "worker_image" {
  description = "ECR image URI for the Worker"
  type        = string
  default     = "424999960857.dkr.ecr.us-east-1.amazonaws.com/trading-platform/worker:latest"
}

variable "alarm_email" {
  description = "Email for alarm notifications"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Root domain"
  type        = string
  default     = "platform-test.click"
}
