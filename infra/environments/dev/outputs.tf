output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "app_url" {
  description = "Application URL"
  value       = "https://dev.${var.domain_name}"
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "cert_validation_records" {
  description = "Add these CNAME records in your DNS to validate the certificate"
  value       = module.dns.domain_validation_options
}

output "sns_topic_arn" {
  description = "SNS topic ARN for deployment notifications"
  value       = module.observability.sns_topic_arn
}
