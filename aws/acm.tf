# aws_installation.py tf_acm and wait_acm: post the ACM DNS challenge to the
# Saturn manager, which owns the saturnenterprise.io zone and writes the
# record after checking it is under the customer's domain, then wait for
# ACM to issue the certificate. TLS then terminates on the load balancer
# with this certificate, as on every saturn-aws install.

locals {
  acm_arn = nonsensitive(module.acm.acm_results["acm_arn"])
}

resource "terraform_data" "acm_dns_challenge" {
  triggers_replace = [local.acm_arn]

  provisioner "local-exec" {
    # Same payload as aws_config.py acm_registration_payload. The bootstrap
    # token authenticates the call without being spent; the operator
    # exchanges it later.
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
      CHALLENGE_NAME  = module.acm.acm_results["dns_challenge_name"]
      CHALLENGE_VALUE = module.acm.acm_results["dns_challenge_rec"]
      CHALLENGE_TYPE  = module.acm.acm_results["dns_challenge_type"]
    }
  }
}

resource "aws_acm_certificate_validation" "default" {
  certificate_arn = local.acm_arn

  timeouts {
    create = "45m"
  }

  depends_on = [terraform_data.acm_dns_challenge]
}
