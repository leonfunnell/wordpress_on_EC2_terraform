resource "aws_efs_file_system" "wordpress_efs" {
   creation_token = "efs_token"
   performance_mode = "generalPurpose"
   throughput_mode = "bursting"
  tags = {
    Name    = "WordPress EFS"
    Project = var.project_name
  }
}

resource "aws_efs_mount_target" "wordpress_efs_mount" {
  file_system_id  = aws_efs_file_system.wordpress_efs.id
  subnet_id       = aws_instance.wordpress_server.subnet_id
  security_groups = [aws_security_group.wordpress_sg.id]
}

