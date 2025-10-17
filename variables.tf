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
  description = "The VPC ID to deploy resources into. If not set, a new VPC will be created."
  default     = ""
}

variable "subnet_id" {
  type        = string
  description = "The Subnet ID to deploy resources into. If not set, a new subnet will be created."
  default     = ""
}

# Cloud/domain settings (also used for ALB)
variable "domain_name" {
  type        = string
  description = "Fully qualified domain name for the site (e.g., www.example.com)"
  default     = ""
}

variable "route53_zone_id" {
  type        = string
  description = "Optional Route53 public hosted zone ID for the domain. If empty, DNS records will be skipped."
  default     = ""
}

variable "overwrite_dns_records" {
  type        = bool
  description = "If true, allow Terraform to overwrite existing Route53 A/ALIAS records for the domain."
  default     = false
}

# ALB + SSL
variable "enable_alb" {
  type        = bool
  description = "Enable an internet-facing Application Load Balancer for the site"
  default     = false
}

variable "alb_certificate_arn" {
  type        = string
  description = "Existing ACM certificate ARN in the same region as the ALB for HTTPS termination (optional). If blank and route53_zone_id+domain_name provided, Terraform will request/validate a new certificate."
  default     = ""
}

variable "alb_subnet_ids" {
  type        = list(string)
  description = "When using an existing VPC (vpc_id set), provide at least two public subnet IDs in different AZs for the ALB. Ignored when the module creates the VPC."
  default     = []
}

# EC2 instance type
variable "instance_type" {
  type        = string
  description = "EC2 instance type for the WordPress server (e.g., t3.micro, t3.small)."
  default     = "t3.micro"
}

# Optional: enable unlimited CPU credits for burstable instances (t2, t3, t3a, t4g)
variable "cpu_unlimited" {
  type        = bool
  description = "If true, set CPU credit specification to 'unlimited' for T-family burstable instance types."
  default     = false
}
