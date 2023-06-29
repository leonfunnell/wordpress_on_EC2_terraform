resource "aws_iam_policy" "efs_policy" {
  name        = "${var.project_name}_efs_policy"
  description = "Policy for accessing EFS from EC2"

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "elasticfilesystem:*",
        "Resource": "${aws_efs_file_system.wordpress_efs.arn}"
      }
    ]
  }
  EOF
}

resource "aws_iam_role" "ec2_efs_role" {
  name = "${var.project_name}_ec2_efs_role"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "efs_policy_attach" {
  role       = aws_iam_role.ec2_efs_role.name
  policy_arn = aws_iam_policy.efs_policy.arn
}

resource "aws_iam_user" "efs_user" {
  name = "${var.project_name}_efs_user"
}

resource "aws_iam_access_key" "efs_user" {
  user = aws_iam_user.efs_user.name
}
