# Application Load Balancer + optional ACM certificate (regional)

locals {
  alb_enabled = var.enable_alb
  base_name   = replace(replace(var.project_name, "_", "-"), " ", "-")
  alb_name    = substr("${local.base_name}-alb", 0, 32)
  tg_name     = substr("${local.base_name}-tg", 0, 32)
}

# ALB security group
resource "aws_security_group" "alb_sg" {
  count       = local.alb_enabled ? 1 : 0
  name_prefix = "${var.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = local.effective_vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-alb-sg"
    Project = var.project_name
  }
}

# ALB
resource "aws_lb" "wp" {
  count              = local.alb_enabled ? 1 : 0
  name               = local.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg[0].id]
  subnets            = local.effective_subnet_ids

  tags = {
    Name    = "${var.project_name}-alb"
    Project = var.project_name
  }
}

# Target group for the instance
resource "aws_lb_target_group" "wp" {
  count    = local.alb_enabled ? 1 : 0
  name     = local.tg_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = local.effective_vpc_id

  health_check {
    enabled  = true
    path     = "/"
    protocol = "HTTP"
  }
}

# Attach the instance to the target group
resource "aws_lb_target_group_attachment" "wp" {
  count            = local.alb_enabled ? 1 : 0
  target_group_arn = aws_lb_target_group.wp[0].arn
  target_id        = aws_instance.wordpress_server.id
  port             = 80
}

# If a cert ARN is not provided but we have Route53 zone + domain, request one and auto-validate via DNS
resource "aws_acm_certificate" "alb" {
  count             = local.alb_enabled && var.domain_name != "" && var.route53_zone_id != "" && var.alb_certificate_arn == "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "alb_cert_validation" {
  for_each = (local.alb_enabled && var.domain_name != "" && var.route53_zone_id != "" && var.alb_certificate_arn == "") ? { for dvo in aws_acm_certificate.alb[0].domain_validation_options : dvo.domain_name => { name = dvo.resource_record_name, type = dvo.resource_record_type, value = dvo.resource_record_value } } : {}
  allow_overwrite = var.overwrite_dns_records
  zone_id         = var.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.value]
}

resource "aws_acm_certificate_validation" "alb" {
  count = local.alb_enabled && var.domain_name != "" && var.route53_zone_id != "" && var.alb_certificate_arn == "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.alb[0].arn
  validation_record_fqdns = [for r in aws_route53_record.alb_cert_validation : r.fqdn]
}

# Determine if HTTPS should be enabled on ALB
locals {
  alb_effective_cert_arn = var.alb_certificate_arn != "" ? var.alb_certificate_arn : (length(aws_acm_certificate.alb) > 0 ? aws_acm_certificate.alb[0].arn : "")
  alb_use_https          = local.alb_enabled && local.alb_effective_cert_arn != ""
}

# HTTP listener - forward to target group or redirect to HTTPS if enabled
resource "aws_lb_listener" "http" {
  count             = local.alb_enabled ? 1 : 0
  load_balancer_arn = aws_lb.wp[0].arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.alb_use_https ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.alb_use_https ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.wp[0].arn
    }
  }
}

# HTTPS listener (only if we have a certificate)
resource "aws_lb_listener" "https" {
  count             = local.alb_use_https ? 1 : 0
  load_balancer_arn = aws_lb.wp[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = local.alb_effective_cert_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wp[0].arn
  }
  depends_on = [aws_acm_certificate_validation.alb]
}
