#!/bin/bash

source variables.sh

# Find the latest Ubuntu LTS AMI (futureproof, always picks latest xx.04)
AMI=$(aws ec2 describe-images --owners 099720109477 \
  --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-*' 'Name=state,Values=available' \
  --region $AWS_REGION --profile $AWS_PROFILE \
  --query "Images[?contains(Name, '.04')].{Name:Name,ImageId:ImageId,CreationDate:CreationDate}" \
  --output json | \
  jq -r '.[] | select(.Name | test("ubuntu-[a-z]+-[0-9]{2}\\.04-")) | [.CreationDate, .ImageId] | @tsv' | \
  sort | tail -n1 | cut -f2
)

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
