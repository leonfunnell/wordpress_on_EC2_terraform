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

# CloudFront/SSL/Domain variables
variable "enable_cloudfront" {
  type        = bool
  description = "Enable CloudFront distribution with custom domain and SSL"
  default     = false
}

variable "domain_name" {
  type        = string
  description = "Fully qualified domain name for the site (e.g., www.example.com)"
  default     = ""
}

variable "route53_zone_id" {
  type        = string
  description = "Optional Route53 public hosted zone ID for the domain. If empty, DNS records will be printed for manual creation on external DNS."
  default     = ""
}

variable "overwrite_dns_records" {
  type        = bool
  description = "If true, allow Terraform to overwrite existing Route53 A/CNAME records for the domain."
  default     = false
}

variable "use_existing_certificate" {
  type        = bool
  description = "If true, use an existing ACM certificate ARN (in us-east-1) instead of creating/validating one."
  default     = false
}

variable "existing_certificate_arn" {
  type        = string
  description = "Existing ACM certificate ARN in us-east-1 to use with CloudFront (required if use_existing_certificate = true and no Route53 zone)."
  default     = ""
}
