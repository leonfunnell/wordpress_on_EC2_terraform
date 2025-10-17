# Route53 records for site A/ALIAS

# A record to EIP if ALB disabled
resource "aws_route53_record" "site_a_eip" {
  count           = var.domain_name != "" && var.route53_zone_id != "" && !var.enable_alb ? 1 : 0
  zone_id         = var.route53_zone_id
  name            = var.domain_name
  type            = "A"
  ttl             = 300
  records         = [aws_eip.wordpress_eip.public_ip]
  allow_overwrite = var.overwrite_dns_records
}

# ALIAS to ALB if enabled
resource "aws_route53_record" "site_alias_alb" {
  count           = var.domain_name != "" && var.route53_zone_id != "" && var.enable_alb ? 1 : 0
  zone_id         = var.route53_zone_id
  name            = var.domain_name
  type            = "A"
  allow_overwrite = var.overwrite_dns_records
  alias {
    name                   = aws_lb.wp[0].dns_name
    zone_id                = aws_lb.wp[0].zone_id
    evaluate_target_health = false
  }
}
