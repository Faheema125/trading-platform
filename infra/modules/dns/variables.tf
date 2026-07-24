variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "domain_name" {
  description = "Root domain name (e.g., platform-test.click)"
  type        = string
}

variable "subdomain" {
  description = "Subdomain for this environment (e.g., dev)"
  type        = string
}
