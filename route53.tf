# Route53 records
# If CloudFront is enabled with a certificate, point domain to CF; otherwise point to EIP

resource "aws_route53_record" "wordpress_site" {
  count = var.domain_name != "" && var.route53_zone_id != "" && !(var.enable_cloudfront && var.use_existing_certificate && var.existing_certificate_arn != "") ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300

  records = [aws_eip.wordpress_eip.public_ip]

  allow_overwrite = var.overwrite_dns_records
}
