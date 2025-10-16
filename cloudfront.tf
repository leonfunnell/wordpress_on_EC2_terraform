# Optional CloudFront distribution for the site
# Requires: enable_cloudfront = true
# Origin is the EC2 instance public DNS (avoids alias loop)

locals {
  use_cf = var.enable_cloudfront && var.domain_name != ""
}

resource "aws_cloudfront_distribution" "wp" {
  count = local.use_cf ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} WordPress"
  default_root_object = "index.php"

  aliases = var.use_existing_certificate && var.existing_certificate_arn != "" ? [var.domain_name] : []

  origin {
    domain_name = aws_instance.wordpress_server.public_dns
    origin_id   = "wp-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "wp-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      cookies { forward = "all" }
    }

    min_ttl     = 0
    default_ttl = 300
    max_ttl     = 3600
  }

  # Allow admin/login POSTs through CloudFront
  ordered_cache_behavior {
    path_pattern           = "/wp-login.php"
    allowed_methods        = ["GET","HEAD","OPTIONS","PUT","POST","PATCH","DELETE"]
    cached_methods         = ["GET","HEAD"]
    target_origin_id       = "wp-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      cookies { forward = "all" }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  ordered_cache_behavior {
    path_pattern           = "/wp-admin/*"
    allowed_methods        = ["GET","HEAD","OPTIONS","PUT","POST","PATCH","DELETE"]
    cached_methods         = ["GET","HEAD"]
    target_origin_id       = "wp-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      cookies { forward = "all" }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.use_existing_certificate && var.existing_certificate_arn != "" ? var.existing_certificate_arn : null
    ssl_support_method             = var.use_existing_certificate && var.existing_certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
    cloudfront_default_certificate = !(var.use_existing_certificate && var.existing_certificate_arn != "")
  }
}

# Route 53 alias to CloudFront, only when a cert/alias is configured
resource "aws_route53_record" "cf_alias" {
  count   = local.use_cf && var.route53_zone_id != "" && var.use_existing_certificate && var.existing_certificate_arn != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.wp[0].domain_name
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront hosted zone id (global)
    evaluate_target_health = false
  }

  allow_overwrite = var.overwrite_dns_records
}
