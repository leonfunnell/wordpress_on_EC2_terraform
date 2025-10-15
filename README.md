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
- Optional: Custom domain + Route53 A-record to EC2 EIP
- Optional: CPU credit mode control for burstable instances

# Optional: Point a custom domain at the EC2 EIP (Route53)
- Set in variables.sh:
  - DOMAIN_NAME="www.example.com"
  - ROUTE53_ZONE_ID="Z123456ABCDEFG"
- Terraform will create a Route53 A record pointing to the instance's Elastic IP.
- If the record already exists and you want Terraform to overwrite it, set:
  - OVERWRITE_DNS_RECORDS=true

# Optional: Custom domain + SSL + CloudFront (future extension)
- Variables are scaffolded for CloudFront/ACM usage but distribution/cert resources are not included in this branch.
- If/when added, you will be able to:
  - ENABLE_CLOUDFRONT=true
  - Use Route53 for automatic DNS and ACM validation or external DNS with manual validation.

# Optional: CPU credits (T-family burstable instances)
- To use unlimited CPU credits on T-family instances (t2/t3/t3a/t4g), set in variables.sh:
  - CPU_UNLIMITED=true
- Default is false (standard credit mode). Has no effect on non-burstable instance families.

# Extending
- You can add CloudFront/SSL, Route53, or other AWS services via Terraform for production use.
- Easily customize plugins, themes, or additional configuration in user_data.sh.

# Tested
- Full WordPress deployment, plugin/theme/media updates, and S3 backup support (UpdraftPlus) are working out of the box.
