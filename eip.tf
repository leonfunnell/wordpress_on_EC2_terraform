resource "aws_eip" "wordpress_eip" {
  count  = var.enable_eip && !var.enable_alb ? 1 : 0
  domain = "vpc"
}

resource "aws_eip_association" "eip_assoc" {
  count         = var.enable_eip && !var.enable_alb ? 1 : 0
  instance_id   = aws_instance.wordpress_server.id
  allocation_id = aws_eip.wordpress_eip[0].id
}

output "wordpress_server_public_ip" {
  description = "Public IP of the WordPress server (EIP when enabled, otherwise instance public IP)"
  value       = var.enable_eip && !var.enable_alb ? aws_eip.wordpress_eip[0].public_ip : aws_instance.wordpress_server.public_ip
}
