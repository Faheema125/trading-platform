# ─────────────────────────────────────────────────────────────
# ACM Certificate
# 
# Creates the certificate in this account.
# DNS validation records must be added MANUALLY in the account
# where the domain's Route53 hosted zone lives.
# ─────────────────────────────────────────────────────────────

resource "aws_acm_certificate" "main" {
  domain_name       = "${var.subdomain}.${var.domain_name}"
  validation_method = "DNS"

  tags = {
    Name        = "${var.environment}-certificate"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}
