output "certificate_arn" {
  description = "ARN of the ACM certificate (pending validation)"
  value       = aws_acm_certificate.main.arn
}

output "domain_validation_options" {
  description = "DNS records to add manually for certificate validation"
  value       = aws_acm_certificate.main.domain_validation_options
}

output "fqdn" {
  description = "Fully qualified domain name for this environment"
  value       = "${var.subdomain}.${var.domain_name}"
}
