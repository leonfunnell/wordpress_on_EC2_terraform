# Generate new private key
resource "tls_private_key" "wordpress_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}_key_pair"
  public_key = tls_private_key.wordpress_key.public_key_openssh
}

# save key file for ssh
resource "local_file" "ssh_key" {
  filename = "wordpress_key.pem"
  content = tls_private_key.wordpress_key.private_key_openssh
  file_permission = "0400" 
}

