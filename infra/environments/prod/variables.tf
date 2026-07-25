variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Root domain"
  type        = string
  default     = "platform-test.click"
}

variable "api_image" {
  description = "ECR image URI for the API"
  type        = string
}

variable "worker_image" {
  description = "ECR image URI for the Worker"
  type        = string
}

variable "alarm_email" {
  description = "Email for alarm notifications"
  type        = string
  default     = ""
}
