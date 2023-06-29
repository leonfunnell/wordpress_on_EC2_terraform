#!/bin/bash

export AWS_PROFILE=patronwills
export AWS_REGION=eu-west-2
export PROJECT_NAME=pwwp
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
