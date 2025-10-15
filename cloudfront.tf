locals {
  cf_enabled = var.enable_cloudfront && var.domain_name != ""
  use_r53    = length(var.route53_zone_id) > 0
}

# ACM certificate for CloudFront must be in us-east-1
resource "aws_acm_certificate" "cf" {
  provider          = aws.us_east_1
  count             = local.cf_enabled && !var.use_existing_certificate ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# If using Route53, create validation records automatically
resource "aws_route53_record" "cf_cert_validation" {
  for_each = local.cf_enabled && !var.use_existing_certificate && local.use_r53 ? {
    for dvo in aws_acm_certificate.cf[0].domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "cf" {
  provider = aws.us_east_1
  count    = local.cf_enabled && !var.use_existing_certificate && local.use_r53 ? 1 : 0

  certificate_arn         = aws_acm_certificate.cf[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cf_cert_validation : r.value[0]]
}

# Decide which certificate ARN to use
locals {
  cf_cert_arn = var.use_existing_certificate ? var.existing_certificate_arn : (local.cf_enabled ? aws_acm_certificate.cf[0].arn : null)
}

# CloudFront distribution (created only when we have a cert path: either existing ARN or Route53-managed validation)
resource "aws_cloudfront_distribution" "wp" {
  count      = local.cf_enabled && (var.use_existing_certificate || local.use_r53) ? 1 : 0
  enabled    = true
  depends_on = [aws_acm_certificate_validation.cf]

  aliases = [var.domain_name]

  origin {
    domain_name = aws_instance.wordpress_server.public_dns
    origin_id   = "wp_origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "wp_origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    compress        = true

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 300
    max_ttl     = 600
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = local.cf_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  price_class = "PriceClass_100"
}

# Route53 alias to CloudFront if we manage the zone here
resource "aws_route53_record" "cf_alias" {
  count   = local.cf_enabled && local.use_r53 ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.wp[0].domain_name
    zone_id                = aws_cloudfront_distribution.wp[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# Helpful outputs for external DNS workflows
output "certificate_dns_validation_records" {
  description = "DNS records to create for ACM validation when not using Route53 (external DNS). Create these CNAMEs at your DNS provider."
  value = local.cf_enabled && !var.use_existing_certificate && !local.use_r53 ? [
    for dvo in aws_acm_certificate.cf[0].domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ] : null
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name (use as CNAME target if managing DNS externally)."
  value       = local.cf_enabled && (var.use_existing_certificate || local.use_r53) ? aws_cloudfront_distribution.wp[0].domain_name : null
}

output "external_dns_instructions" {
  description = "If your domain is not in Route53, create: 1) the ACM validation CNAME(s) above, wait for ISSUED; 2) a CNAME from domain_name to CloudFront domain (or use ALIAS/ANAME at apex if supported)."
  value       = local.cf_enabled && !local.use_r53 ? {
    domain          = var.domain_name
    cloudfront_cname_target = (var.use_existing_certificate || length(aws_cloudfront_distribution.wp) > 0) ? aws_cloudfront_distribution.wp[0].domain_name : "<pending until certificate is ISSUED and distribution created>"
  } : null
}
