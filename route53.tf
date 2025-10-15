# Create an A record in Route53 pointing the domain to the EC2 EIP
# Only created when both domain_name and route53_zone_id are provided

resource "aws_route53_record" "wordpress_site" {
  count = var.domain_name != "" && var.route53_zone_id != "" ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300

  records = [aws_eip.wordpress_eip.public_ip]

  # Allow Terraform to overwrite an existing record with the same name/type when enabled
  allow_overwrite = var.overwrite_dns_records
}
