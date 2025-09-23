#!/bin/bash
# must be run as sudo/root

export DEBIAN_FRONTEND=noninteractive
RED='\033[0;31m'
NC='\033[0m' # No Color

source variables.sh

TMP=`mktemp -d`
cd $TMP
set -e

# Set up EFS
echo -e ${RED}running apt-get update...
apt-get -yq update
echo -e ${RED}running apt-get upgrade...
apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -yq upgrade
echo -e ${RED}running apt-get update...
apt-get -yq update

echo -e ${RED}installing nfs-common...
apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -yq install nfs-common

# Wait for EFS DNS to resolve (max 2 minutes)
for i in {1..24}; do
  getent hosts $EFS_DNSNAME && break
  echo "Waiting for EFS DNS to resolve..."
  sleep 5
done

# Ensure mount point exists before mounting
mkdir -p /var/www/html

# Retry EFS mount up to 5 times
for i in {1..5}; do
  mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $EFS_DNSNAME:/  /var/www/html && break
  echo "Retrying EFS mount..."
  sleep 5
done

mount | grep /var/www/html
echo -e ${RED}installing apache2 mysql-server php libapache2-mod-php php-mysql vsftpd unzip
apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -yq install apache2 mysql-server php libapache2-mod-php php-mysql vsftpd unzip

# Install AWS CLI v2
sudo apt-get install -y curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -o /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install

# Set correct permissions for WordPress
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Ensure /tmp is world-writable with sticky bit
chmod 1777 /tmp

# Generate wp-config.php if it doesn't exist
if [ ! -f /var/www/html/wp-config.php ]; then
cat <<EOF > /var/www/html/wp-config.php
<?php
define('DB_NAME', '${DB_NAME}');
define('DB_USER', '${DB_USER}');
define('DB_PASSWORD', '${DB_PASSWORD}');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
define('FS_METHOD', 'direct');

// Authentication Unique Keys and Salts.

define('AUTH_KEY',         '$(openssl rand -base64 32)');
define('SECURE_AUTH_KEY',  '$(openssl rand -base64 32)');
define('LOGGED_IN_KEY',    '$(openssl rand -base64 32)');
define('NONCE_KEY',        '$(openssl rand -base64 32)');
define('AUTH_SALT',        '$(openssl rand -base64 32)');
define('SECURE_AUTH_SALT', '$(openssl rand -base64 32)');
define('LOGGED_IN_SALT',   '$(openssl rand -base64 32)');
define('NONCE_SALT',       '$(openssl rand -base64 32)');

$table_prefix  = 'wp_';

define('WP_DEBUG', false);

if ( !defined('ABSPATH') )
    define('ABSPATH', dirname(__FILE__) . '/');

require_once(ABSPATH . 'wp-settings.php');
EOF
fi

# Add FTP config for plugin/theme updates
cat <<EOT >> /var/www/html/wp-config.php

define('FTP_HOST', 'localhost');
define('FTP_USER', '${SFTP_USER}');
define('FTP_PASS', '${SFTP_PASSWORD}');
EOT

# Mount NFS and configure fstab
echo -e ${RED}mounting NFS:
echo "$EFS_DNSNAME:/ /var/www/html nfs4 defaults,_netdev 0 0" >> /etc/fstab
mount -a
echo -e ${RED}result of mount NFS:
mount | grep /var/www/html && echo -e ${RED}NFS Mounted successfully!

echo -e ${RED}Configure MySQL...
mysql -u root <<-EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "<Directory /var/www/html/>" | tee -a /etc/apache2/sites-available/000-default.conf
echo "    DirectoryIndex index.php index.html" | tee -a /etc/apache2/sites-available/000-default.conf
echo "</Directory>" | tee -a /etc/apache2/sites-available/000-default.conf
systemctl restart apache2

echo -e ${RED}Install WordPress...
wget -c http://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* /var/www/html/

# Download plugins to $TMP
wget https://downloads.wordpress.org/plugin/cookie-notice.2.4.8.zip
wget https://downloads.wordpress.org/plugin/all-in-one-wp-migration.7.75.zip 
wget https://downloads.wordpress.org/plugin/elementor.3.13.4.zip
wget https://downloads.wordpress.org/plugin/updraftplus.1.23.4.zip
wget https://downloads.wordpress.org/plugin/wordfence.7.9.3.zip
wget https://downloads.wordpress.org/plugin/wordpress-importer.0.8.1.zip

# Unzip plugins into the plugins directory
for zip in $TMP/*.zip; do
  unzip "$zip" -d /var/www/html/wp-content/plugins/
done
