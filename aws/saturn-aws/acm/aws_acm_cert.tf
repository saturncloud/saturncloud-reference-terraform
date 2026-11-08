# Wildcard cert for customer subdomain at saturnenterprise.io

resource "aws_acm_certificate" "default" {
  domain_name = var.domain
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  tags = var.tags
}
