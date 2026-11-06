# TLS terminates on the load balancer with an ACM certificate, as on every
# saturn-aws install: AWS holds the key and renews the certificate. This
# replaces saturn-aws's acm stack plus its INSTALL_ACME call and wait loop.
#
# ACM proves the domain with a CNAME under <domain>. Saturn owns the
# saturnenterprise.io zone, so the manager writes that record for us; it
# checks that the name is under the customer's own domain.

resource "aws_acm_certificate" "default" {
  domain_name       = "*.${local.saturn_domain}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  acm_challenge = one(aws_acm_certificate.default.domain_validation_options)
}

resource "terraform_data" "acm_dns_challenge" {
  triggers_replace = [aws_acm_certificate.default.arn]

  provisioner "local-exec" {
    # The bootstrap token authenticates this call without being spent; the
    # operator exchanges it later.
    command = <<-EOT
      set -eu
      body=$(jq -n --arg n "$CHALLENGE_NAME" --arg v "$CHALLENGE_VALUE" --arg t "$CHALLENGE_TYPE" \
        '{"dns-challenge": {name: $n, value: $v, type: $t}}')
      code=$(curl -sS -o /dev/null -w '%%{http_code}' -X POST "$MANAGER_URI/install/acme" \
        -H "Authorization: Bearer $SATURN_TOKEN" -H "Content-Type: application/json" -d "$body")
      [ "$code" = 200 ] || { echo "manager /install/acme returned HTTP $code" >&2; exit 1; }
    EOT
    environment = {
      MANAGER_URI     = var.saturn_manager_uri
      SATURN_TOKEN    = var.saturn_bootstrap_token
      CHALLENGE_NAME  = local.acm_challenge.resource_record_name
      CHALLENGE_VALUE = local.acm_challenge.resource_record_value
      CHALLENGE_TYPE  = local.acm_challenge.resource_record_type
    }
  }
}

resource "aws_acm_certificate_validation" "default" {
  certificate_arn = aws_acm_certificate.default.arn

  timeouts {
    create = "45m"
  }

  depends_on = [terraform_data.acm_dns_challenge]
}
