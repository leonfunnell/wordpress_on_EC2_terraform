resource "aws_instance" "wordpress_server" {
  ami           = var.ami
  instance_type = "t2.micro"

  iam_instance_profile = aws_iam_instance_profile.ec2_efs_profile.name

  key_name = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.wordpress_sg.id]
  subnet_id = local.effective_subnet_id

  depends_on = [aws_efs_file_system.wordpress_efs]

  tags = {
    Name    = "${var.project_name}-server"
    Project = "${var.project_name}"
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo export PROJECT_NAME=${var.project_name}> server_variables.sh
      echo export DB_NAME=${var.db_name} >> server_variables.sh
      echo export DB_USER=${var.db_user} >> server_variables.sh
      echo export DB_PASSWORD=${var.db_password} >> server_variables.sh
      echo export SFTP_USER=${var.sftp_user} >> server_variables.sh
      echo export SFTP_PASSWORD=${var.sftp_password} >> server_variables.sh
      echo export EFS_ID=${aws_efs_file_system.wordpress_efs.id} >> server_variables.sh
      echo export EFS_DNSNAME=${aws_efs_file_system.wordpress_efs.dns_name} >> server_variables.sh
      echo export AWS_REGION=${var.aws_region} >> server_variables.sh
      echo export PUBLIC_IP=${self.public_ip} >> server_variables.sh
    EOT
  }

  provisioner "file" {
    source      = "user_data.sh"
    destination = "/home/ubuntu/user_data.sh"

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file(local_file.ssh_key.filename)
    }
  }

  provisioner "file" {
    source      = "server_variables.sh"
    destination = "/home/ubuntu/variables.sh"

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file(local_file.ssh_key.filename)
    }
  }
}

resource "null_resource" "configure_server" {
  depends_on = [aws_efs_mount_target.wordpress_efs_mount]
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/user_data.sh",
      "chmod +x /home/ubuntu/variables.sh",
      "cd /home/ubuntu",
      "sudo /home/ubuntu/user_data.sh"
    ]
  }
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(local_file.ssh_key.filename)
      host        = aws_eip.wordpress_eip.public_ip
    }
}

resource "aws_iam_instance_profile" "ec2_efs_profile" {
  name = "${var.project_name}_ec2_efs_profile"
  role = aws_iam_role.ec2_efs_role.name
}
