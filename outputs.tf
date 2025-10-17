output "elastic_ip_address" {
  description = "The public IP address assigned to the WordPress server (EIP when enabled)"
  value       = try(aws_eip.wordpress_eip[0].public_ip, null)
}

output "efs_file_system_id" {
  description = "The ID of the EFS file system"
  value       = aws_efs_file_system.wordpress_efs.id
}

output "ssh_command" {
  description = "Command to connect to server"
  value       = var.enable_eip && !var.enable_alb ? "ssh -i wordpress_key.pem ubuntu@${aws_eip.wordpress_eip[0].public_ip}" : "ssh -i wordpress_key.pem ubuntu@${aws_instance.wordpress_server.public_ip}"
}

# Primary site URL depending on ALB+domain or IP fallback
output "site_url" {
  description = "Primary URL for WordPress"
  value       = var.enable_alb && var.domain_name != "" ? (var.alb_certificate_arn != "" || (length(aws_acm_certificate.alb) > 0) ? "https://${var.domain_name}" : "http://${var.domain_name}") : "http://${var.enable_eip && !var.enable_alb ? aws_eip.wordpress_eip[0].public_ip : aws_instance.wordpress_server.public_ip}"
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
