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

# Optional: Domain/SSL/CloudFront
# Set ENABLE_CLOUDFRONT=true to enable CloudFront + SSL for a custom domain.
# If using Route53, set ROUTE53_ZONE_ID to your hosted zone ID to auto-create DNS and validate ACM.
# If using external DNS, leave ROUTE53_ZONE_ID empty. Terraform will output the DNS records you must create
# to validate the certificate. Once issued, set USE_EXISTING_CERTIFICATE=true and provide EXISTING_CERTIFICATE_ARN
# (an ACM cert in us-east-1) to create the CloudFront distribution and finish setup.
export ENABLE_CLOUDFRONT=false
export DOMAIN_NAME=""          # e.g. www.example.com
export ROUTE53_ZONE_ID=""      # e.g. Z123456ABCDEFG (leave blank for external DNS)
export OVERWRITE_DNS_RECORDS=false  # set true to allow Terraform to overwrite existing A/CNAME in Route53
export USE_EXISTING_CERTIFICATE=false
export EXISTING_CERTIFICATE_ARN=""  # required if USE_EXISTING_CERTIFICATE=true

# EC2 instance type (default t3.micro). Examples: t3.small, t3.medium
export INSTANCE_TYPE=t3.micro

# Enable unlimited CPU credits for burstable instances (t2/t3/t3a/t4g). Default: false
export CPU_UNLIMITED=false
