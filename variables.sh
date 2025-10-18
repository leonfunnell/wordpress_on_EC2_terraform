#!/bin/bash

export AWS_PROFILE=default # update to your chosen AWSCLI profile
export AWS_REGION=eu-west-2 # update to your chosen AWS region
export PROJECT_NAME=wordpress_project # update to your chosen project name
export DB_NAME=${PROJECT_NAME}_db
export DB_USER=${PROJECT_NAME}_user
export SFTP_USER=${PROJECT_NAME}_sftp

# Generate a random password for the MySQL user
if [ ! -f "${PROJECT_NAME}_db_password.txt" ]; then
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' > "${PROJECT_NAME}_db_password.txt"
fi
export DB_PASSWORD=$(cat "${PROJECT_NAME}_db_password.txt")

# Generate a random password for the SFTP user
if [ ! -f "${PROJECT_NAME}_sftp_password.txt" ]; then
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' > "${PROJECT_NAME}_sftp_password.txt"
fi
export SFTP_PASSWORD=$(cat "${PROJECT_NAME}_sftp_password.txt")

# Optional: Domain + Route53
export DOMAIN_NAME=""          # e.g. www.example.com
export ROUTE53_ZONE_ID=""      # e.g. Z123456ABCDEFG (leave blank to skip Route53)
export OVERWRITE_DNS_RECORDS=false

# Optional: Use an ALB (recommended for WordPress dynamic sites)
# If ENABLE_ALB=true and DOMAIN_NAME set, Terraform will create an ALB and (optionally) HTTPS listener.
# To enable HTTPS, either:
#  - set ALB_CERTIFICATE_ARN to an ACM cert ARN in the same region; or
#  - leave it blank and provide ROUTE53_ZONE_ID so Terraform can request/validate a new certificate via DNS.
export ENABLE_ALB=false
export ALB_CERTIFICATE_ARN=""

# If deploying to an existing VPC, provide at least two public subnets for ALB
# Comma-separated list: e.g. "subnet-aaa,subnet-bbb". Leave empty to let Terraform create its own VPC/subnets.
export ALB_SUBNET_IDS_CSV=""

# EC2 instance type (default t3.micro). Examples: t3.small, t3.medium
export INSTANCE_TYPE=t3.micro

# Enable unlimited CPU credits for burstable instances (t2/t3/t3a/t4g). Default: false
export CPU_UNLIMITED=false

# Max PHP minor series WordPress should use (prevents selecting unsupported future versions like 8.5)
# Set to the latest series supported by your target WordPress version. Default: 8.4
export WP_MAX_PHP_SERIES=8.4
