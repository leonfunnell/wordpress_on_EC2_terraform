resource "aws_security_group" "wordpress_sg" {
  name_prefix = "${var.project_name}-sg"
  description = "Security group for the WordPress server"
  vpc_id      = local.effective_vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # Instance serves HTTP for ALB target group health checks and traffic
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS not required on instance when using ALB (SSL terminates at ALB)
  # Leaving out port 443 here to simplify and harden surface area

  ingress {
    description = "EFS mount target"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.efs_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name    = "WordPress SG"
    Project = var.project_name
  }
}
