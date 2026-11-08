output "acm_results" {
  value = {
    acm_arn = aws_acm_certificate.default.arn,
    dns_challenge_name = element(tolist(aws_acm_certificate.default.domain_validation_options), 0).resource_record_name,
    dns_challenge_type = element(tolist(aws_acm_certificate.default.domain_validation_options), 0).resource_record_type,
    dns_challenge_rec = element(tolist(aws_acm_certificate.default.domain_validation_options), 0).resource_record_value
  }
  sensitive = true
}