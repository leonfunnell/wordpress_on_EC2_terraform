# wordpress_on_EC2_terraform
Deploy a Wordpress EC2 instance with EIP, EFS and IAM roles. Can be used for DR with a single free-tier server

# Prerequisites:
- An AWS Account
- An IAM user account with Admin rights (or create/destroy over EC2, EFS, IAM)
- AWSCLI and Terraform installed on your BASH prompt
- AWSCLI configured with the keys from the IAM user, with the profile matching above

# Configuration:
Please update the variables.sh with a minimum of your AWSCLI profile (uses 'default' by default)


# Usage
# To deploy:
./deploy_wordpress.sh

# To destroy (Don't do this in production!):
./deploy_wordpress.sh --destroy

