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

output "wordpress_site" {
  description = "URL for Wordpress"
  value       = "http://${aws_eip.wordpress_eip.public_ip}"
}