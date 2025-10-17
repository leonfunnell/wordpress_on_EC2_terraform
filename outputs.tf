output "elastic_ip_address" {
  description = "The public IP address assigned to the WordPress server"
  value       = aws_eip.wordpress_eip.public_ip
}

output "efs_file_system_id" {
  description = "The ID of the EFS file system"
  value       = aws_efs_file_system.wordpress_efs.id
}

output "ssh_command" {
  description = "Command to connect to server"
  value       = "ssh -i wordpress_key.pem ubuntu@${aws_eip.wordpress_eip.public_ip}"
}

# Primary site URL depending on ALB+domain or EIP fallback
output "site_url" {
  description = "Primary URL for WordPress"
  value       = var.enable_alb && var.domain_name != "" ? (var.alb_certificate_arn != "" || (length(aws_acm_certificate.alb) > 0) ? "https://${var.domain_name}" : "http://${var.domain_name}") : "http://${aws_eip.wordpress_eip.public_ip}"
}

# ALB outputs
output "alb_dns_name" {
  description = "ALB DNS name (if enabled)"
  value       = try(aws_lb.wp[0].dns_name, null)
}

output "alb_zone_id" {
  description = "ALB hosted zone ID (for Route53 alias)"
  value       = try(aws_lb.wp[0].zone_id, null)
}
