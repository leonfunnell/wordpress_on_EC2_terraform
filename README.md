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
To deploy:
```
./deploy_wordpress.sh
```
To destroy (Don't do this in production!):
```
./deploy_wordpress.sh --destroy
```

# Features & Components
- Robust AMI selection: Automatically selects the latest Ubuntu LTS AMI by date.
- Automated EC2 provisioning: Launches a WordPress-ready EC2 instance with EIP (static IP).
- Elastic File System (EFS): WordPress files are stored on EFS for durability and easy backup/restore.
- IAM roles: Securely grants EC2 access to EFS and other AWS services.
- Automated MySQL setup: Database and user are created automatically.
- Automatic wp-config.php generation: DB credentials, FS_METHOD, and FTP config are set for plugin/theme updates.
- Plugin/theme/media update support: Directory permissions and FS_METHOD allow updates via the WordPress admin UI.
- FTP/SFTP plugin update support: FTP credentials are auto-configured for seamless plugin/theme updates.
- /tmp permissions: Ensures /tmp is world-writable for plugin/theme updates.
- Required PHP modules: Installs php-xml and php-curl for UpdraftPlus and S3 support.
- AWS CLI v2: Installed using the official AWS installer for compatibility.
- Plugin auto-install: Popular plugins (UpdraftPlus, Elementor, Wordfence, etc.) are downloaded and installed automatically.
- Optional: Custom domain + SSL + CloudFront (see below)

# Optional: Custom domain + SSL + CloudFront
- Enable by setting in variables.sh:
  - ENABLE_CLOUDFRONT=true
  - DOMAIN_NAME="www.example.com"
  - If using Route53: set ROUTE53_ZONE_ID to your hosted zone ID. Terraform will:
    - Create/validate an ACM cert in us-east-1
    - Create a CloudFront distribution using your domain and the cert
    - Create a Route53 ALIAS A record to CloudFront
  - If using external DNS (not Route53):
    - Leave ROUTE53_ZONE_ID empty
    - First apply will output the ACM validation CNAMEs (certificate_dns_validation_records). Create them at your DNS provider and wait for issuance.
    - Then set USE_EXISTING_CERTIFICATE=true and EXISTING_CERTIFICATE_ARN=<your us-east-1 cert ARN> and re-run deploy to create CloudFront.
    - After CloudFront is created, create a CNAME from DOMAIN_NAME to the output cloudfront_domain_name (or ALIAS/ANAME at apex if your provider supports it).

# Extending
- You can add CloudFront/SSL, Route53, or other AWS services via Terraform for production use.
- Easily customize plugins, themes, or additional configuration in user_data.sh.

# Tested
- Full WordPress deployment, plugin/theme/media updates, and S3 backup support (UpdraftPlus) are working out of the box.
