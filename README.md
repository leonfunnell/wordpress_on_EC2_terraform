# wordpress_on_EC2_terraform
Deploy a Wordpress EC2 instance with EIP, EFS and IAM roles. Optional ALB for HTTPS + custom domain. Can be used for DR with a single free-tier server.

# Prerequisites:
- An AWS Account
- An IAM user account with Admin rights (or create/destroy over EC2, EFS, IAM, Route53, ACM, ELB)
- AWSCLI and Terraform installed on your BASH prompt
- AWSCLI configured with the keys from the IAM user, with the profile matching above

# Configuration:
Update variables.sh (at minimum set your AWS profile/region). See ALB/domain options below.

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
- Automated EC2 provisioning: Launches a WordPress-ready EC2 instance.
- Elastic File System (EFS): WordPress files are stored on EFS for durability and easy backup/restore.
- IAM roles: Securely grants EC2 access to EFS and other AWS services.
- Automated MySQL setup: Database and user are created automatically.
- Automatic wp-config.php generation: DB credentials, FS_METHOD, FTP config, and external URL (WP_HOME/SITEURL).
- Plugin/theme/media update support: Directory permissions and FS_METHOD allow updates via the WordPress admin UI.
- Required PHP modules: Installs php-xml and php-curl for UpdraftPlus and S3 support.
- AWS CLI v2: Installed using the official AWS installer for compatibility.
- Plugin auto-install: Popular plugins (UpdraftPlus, Elementor, Wordfence, etc.) are downloaded and installed automatically.
- Optional: Custom domain + Route53 A-record to EC2 EIP or ALIAS to ALB
- Optional: ALB with HTTP->HTTPS redirect and ACM certificate (auto DNS validation via Route53)
- Optional: CPU credit mode control for burstable instances

# Domain and HTTPS options
1) Simple (no domain):
- Leave DOMAIN_NAME empty. Use the Elastic IP output (http).

2) Domain -> EIP (no ALB):
- Set in variables.sh:
  - DOMAIN_NAME="www.example.com"
  - ROUTE53_ZONE_ID="Z123456ABCDEFG"
  - ENABLE_ALB=false
- Route53 A record created to the instance EIP. WordPress URL is set to http://DOMAIN_NAME

3) Domain -> ALB with HTTPS (recommended):
- Set in variables.sh:
  - ENABLE_ALB=true
  - DOMAIN_NAME="www.example.com"
  - ROUTE53_ZONE_ID="Z123456ABCDEFG" (for DNS + ACM validation)
  - OVERWRITE_DNS_RECORDS=true (optional)
- Certificate options:
  a) Auto-issue via Route53: leave ALB_CERTIFICATE_ARN empty. Terraform requests/validates ACM and configures HTTPS + HTTP->HTTPS redirect.
  b) Use existing cert: set ALB_CERTIFICATE_ARN to an ACM ARN in the same region.
- If using your own VPC, provide at least two public subnets in different AZs for the ALB:
  - Set ALB_SUBNET_IDS_CSV="subnet-aaa,subnet-bbb" in variables.sh

# WordPress URL configuration
- The install sets WP_HOME and WP_SITEURL automatically:
  - If ENABLE_ALB=true and DOMAIN_NAME set: https://DOMAIN_NAME
  - Else if DOMAIN_NAME set without ALB: http://DOMAIN_NAME
  - Else: http://EIP

# Optional: CPU credits (T-family burstable instances)
- To use unlimited CPU credits on T-family instances (t2/t3/t3a/t4g), set in variables.sh:
  - CPU_UNLIMITED=true

# Outputs
- site_url: Primary URL for the site
- alb_dns_name, alb_zone_id (when ALB enabled)
- elastic_ip_address: Instance EIP (always created)
- ssh_command

# Extending
- Add WAF, ALB security policies, autoscaling, RDS, backups, etc.
- Customize plugins, themes, or additional configuration in user_data.sh.
