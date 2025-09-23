#!/bin/bash

source variables.sh

# Set AWS_PROFILE and AWS_REGION with precedence: env > variables.sh > ~/.aws/config
: "${AWS_PROFILE:=${AWS_PROFILE_FROM_VARS}}"
: "${AWS_REGION:=${AWS_REGION_FROM_VARS}}"

# If AWS_PROFILE is not set, default to "default"
if [ -z "$AWS_PROFILE" ]; then
  AWS_PROFILE="default"
fi

# Get region for the profile from ~/.aws/config
if [ -z "$AWS_REGION" ]; then
  AWS_REGION=$(awk -v profile="$AWS_PROFILE" '
    $0 == "[profile "profile"]" {f=1; next}
    $0 ~ /^\[.*\]/ {f=0}
    f && /^region/ {print $3; exit}
  ' ~/.aws/config)
fi

if [ -z "$AWS_REGION" ]; then
  echo "ERROR: AWS_REGION not set and could not be determined from ~/.aws/config" >&2
  exit 1
fi

# Build AWS CLI profile/region arguments
AWS_CLI_PROFILE_ARG=""
if [ -n "$AWS_PROFILE" ]; then
  AWS_CLI_PROFILE_ARG="--profile $AWS_PROFILE"
fi

AWS_CLI_REGION_ARG=""
if [ -n "$AWS_REGION" ]; then
  AWS_CLI_REGION_ARG="--region $AWS_REGION"
fi

# Find the latest Ubuntu LTS AMI (dynamic, futureproof, matches ssd and ssd-gp3, always picks latest xx.04 with even year)
AMI=$(aws ec2 describe-images --owners 099720109477 \
  --filters 'Name=name,Values=ubuntu/images/hvm-ssd*/ubuntu-*-amd64-server-*' 'Name=state,Values=available' \
  $AWS_CLI_REGION_ARG $AWS_CLI_PROFILE_ARG \
  --query "Images[].{Name:Name,ImageId:ImageId}" \
  --output json | \
  jq -r '
    .[]
    | select(.Name? and (.Name | type == "string") and (.Name | test("-[0-9]{2}\\.04-")))
    | .Name as $name
    | capture("-([0-9]{2})\\.04-") as $c
    | select((($c[1] | tonumber) % 2) == 0)
    | [$name, .ImageId, ($c[1] | tonumber)]
    | @tsv
  ' | sort -k3,3n | tail -n1 | cut -f2
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
