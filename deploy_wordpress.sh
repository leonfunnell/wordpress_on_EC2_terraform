#!/bin/bash

source variables.sh

# Find the latest Ubuntu LTS AMI (e.g., 24.04, 22.04, etc.)
AMI=$(aws ec2 describe-images --owners 099720109477 --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text --region $AWS_REGION --profile $AWS_PROFILE)

case "$1" in
--destroy)
    echo "Destroying the Wordpress infrastructure..."
    terraform init
    terraform destroy \
        -var="aws_profile=$AWS_PROFILE" \
        -var="aws_region=$AWS_REGION" \
        -var="ami=$AMI" \
        -var="project_name=$PROJECT_NAME" \
        -var="db_name=$DB_NAME" \
        -var="db_user=$DB_USER" \
        -var="db_password=$DB_PASSWORD" \
        -var="sftp_user=$SFTP_USER" \
        -var="sftp_password=$SFTP_PASSWORD" \
        -auto-approve
    ;;
*)
    echo "Deploying the Wordpress infrastructure..."
    terraform init
    terraform apply \
        -var="aws_profile=$AWS_PROFILE" \
        -var="aws_region=$AWS_REGION" \
        -var="ami=$AMI" \
        -var="project_name=$PROJECT_NAME" \
        -var="db_name=$DB_NAME" \
        -var="db_user=$DB_USER" \
        -var="db_password=$DB_PASSWORD" \
        -var="sftp_user=$SFTP_USER" \
        -var="sftp_password=$SFTP_PASSWORD" \
        -auto-approve
    ;;
esac
