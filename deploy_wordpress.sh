#!/bin/bash

source variables.sh

# Set AWS_PROFILE and AWS_REGION with precedence: env > variables.sh > ~/.aws/config
: "${AWS_PROFILE:=${AWS_PROFILE_FROM_VARS}}"
: "${AWS_REGION:=${AWS_REGION_FROM_VARS}}"

if [ -z "$AWS_PROFILE" ]; then
  AWS_PROFILE=$(awk '/^\[default\]/{f=1} f && /^region/{print "default"; exit}' ~/.aws/config 2>/dev/null)
fi

if [ -z "$AWS_REGION" ]; then
  AWS_REGION=$(awk -v profile="${AWS_PROFILE:-default}" '
    $0 == "[profile "profile"]" {f=1; next}
    $0 ~ /^\[.*\]/ {f=0}
    f && /^region/ {print $3; exit}
    ' ~/.aws/config 2>/dev/null)
  # Fallback to default profile if not found
  if [ -z "$AWS_REGION" ]; then
    AWS_REGION=$(awk '/^\[default\]/{f=1} f && /^region/ {print $3; exit}' ~/.aws/config 2>/dev/null)
  fi
fi

if [ -z "$AWS_REGION" ] || [ -z "$AWS_PROFILE" ]; then
  echo "ERROR: AWS_REGION and/or AWS_PROFILE not set and could not be determined from ~/.aws/config" >&2
  exit 1
fi

# Find the latest Ubuntu LTS AMI (dynamic, futureproof, matches ssd and ssd-gp3, always picks latest xx.04 with even year)
AMI=$(aws ec2 describe-images --owners 099720109477 \
  --filters 'Name=name,Values=ubuntu/images/hvm-ssd*/ubuntu-*-amd64-server-*' 'Name=state,Values=available' \
  --region $AWS_REGION --profile $AWS_PROFILE \
  --query "Images[].{Name:Name,ImageId:ImageId}" \
  --output json | \
  jq -r '
    .[] | select(.Name? and (.Name | test("ubuntu-[a-z]+-[0-9]{2}\\.04-"))) |
    .Name as $name |
    capture("ubuntu-[a-z]+-(?<year>[0-9]{2})\\.04-") as $c |
    select((($c.year | tonumber) % 2) == 0) |
    [$name, .ImageId, ($c.year | tonumber)] | @tsv
  ' | \
  sort -k3,3n | tail -n1 | cut -f2
)

echo "Selected Ubuntu LTS AMI: $AMI"

if [ -z "$AMI" ]; then
  echo "ERROR: No Ubuntu LTS AMI found! Check your AWS credentials, region, and jq/AMI filter." >&2
  exit 1
fi

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
