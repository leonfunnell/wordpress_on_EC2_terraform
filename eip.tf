
resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.wordpress_server.id
  allocation_id = aws_eip.wordpress_eip.id
}


resource "aws_eip" "wordpress_eip" {
  domain = "vpc"
}

output "wordpress_server_public_ip" {
  value       = aws_eip.wordpress_eip.public_ip
  description = "Public IP of the WordPress server"
}
