variable "aws_profile" {
  type        = string
  description = "AWS profile to use for deployment"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "ami" {
  type        = string
  description = "AMI ID to use for EC2 instance"
}

variable "project_name" {
  type        = string
  description = "Project name to tag resources"
}

variable "db_name" {
  type        = string
  description = "Database name for WordPress"
}

variable "db_user" {
  type        = string
  description = "Database username for WordPress"
}

variable "db_password" {
  type        = string
  description = "Database password for WordPress"
}

variable "sftp_user" {
  type        = string
  description = "Username for SFTP access"
}

variable "sftp_password" {
  type        = string
  description = "Password for SFTP access"
}

variable "ssh_allowed_cidr" {
  type        = string
  description = "CIDR block allowed to SSH (default: your IP)"
  default     = "0.0.0.0/0"
}

variable "efs_allowed_cidr" {
  type        = string
  description = "CIDR block allowed to access EFS (default: VPC CIDR)"
  default     = "0.0.0.0/0"
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID to deploy resources into. If not set, the default VPC will be used."
  default     = ""
}
