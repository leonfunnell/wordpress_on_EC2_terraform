#!/bin/bash
# must be run as sudo/root

set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
RED='\033[0;31m'
NC='\033[0m' # No Color

# Logging
LOG_FILE=/var/log/wp-user-data.log
mkdir -p /var/log
{
  echo "===== $(date -u +"%Y-%m-%dT%H:%M:%SZ") user_data.sh start ====="
} >> "$LOG_FILE" 2>&1
exec > >(tee -a "$LOG_FILE") 2>&1

# Load variables
if [ -f /home/ubuntu/variables.sh ]; then
  # shellcheck disable=SC1091
  source /home/ubuntu/variables.sh
elif [ -f ./variables.sh ]; then
  # shellcheck disable=SC1091
  source ./variables.sh
else
  echo "WARN: variables.sh not found; proceeding with env defaults"
fi

TMP=$(mktemp -d)
cd "$TMP"

echo "Step: apt update/upgrade"
apt-get -yq update
apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -yq upgrade
apt-get -yq update

echo "Step: install nfs-common curl unzip"
apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -yq install nfs-common curl unzip

# Determine target for EFS mount (prefer DNS, fallback to IP if DNS doesn't resolve)
MOUNT_TARGET="${EFS_DNSNAME:-}"
if [ -z "$MOUNT_TARGET" ] && [ -n "${EFS_IP:-}" ]; then
  MOUNT_TARGET="$EFS_IP"
fi

echo "Step: wait for EFS DNS (or use IP) - target: $MOUNT_TARGET"
for i in {1..36}; do # wait up to 3 minutes for DNS
  if [ -n "${EFS_DNSNAME:-}" ] && getent hosts "$EFS_DNSNAME" >/dev/null 2>&1; then
    MOUNT_TARGET="$EFS_DNSNAME"
    break
  fi
  sleep 5
  if [ $i -eq 36 ] && [ -n "${EFS_IP:-}" ]; then
    echo "EFS DNS not resolvable; fallback to IP $EFS_IP"
    MOUNT_TARGET="$EFS_IP"
  fi
done

# Ensure mount point exists before mounting
mkdir -p /var/www/html

echo "Step: mount EFS to /var/www/html"
for i in {1..10}; do
  if mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${MOUNT_TARGET}:/ /var/www/html; then
    break
  fi
  echo "Retrying EFS mount... ($i)"
  sleep 6
  if [ "$MOUNT_TARGET" = "${EFS_DNSNAME:-}" ] && [ -n "${EFS_IP:-}" ] && ! getent hosts "$EFS_DNSNAME" >/dev/null 2>&1; then
    echo "Switching to EFS IP $EFS_IP"
    MOUNT_TARGET="$EFS_IP"
  fi
done
mount | grep /var/www/html

echo "Step: install LAMP + tools"
apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -yq install \
  apache2 mysql-server php libapache2-mod-php php-mysql vsftpd php-xml php-curl

echo "Step: install/update AWS CLI v2"
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -o /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install --update || true

echo "Step: enable Apache rewrite"
a2enmod rewrite || true

# Install WordPress core files if not present (EFS will be empty on first boot)
if [ ! -f /var/www/html/wp-settings.php ]; then
  echo "Step: download and install WordPress core"
  wget -q -c http://wordpress.org/latest.tar.gz
  tar -xzf latest.tar.gz
  rsync -a wordpress/ /var/www/html/
fi

# Generate wp-config.php from sample if needed
if [ ! -f /var/www/html/wp-config.php ]; then
  echo "Step: create wp-config.php from sample"
  cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
fi

echo "Step: configure wp-config.php (DB creds, salts, FS/FTP)"
sed -i "s/database_name_here/${DB_NAME}/" /var/www/html/wp-config.php
sed -i "s/username_here/${DB_USER}/" /var/www/html/wp-config.php
sed -i "s/password_here/${DB_PASSWORD}/" /var/www/html/wp-config.php

curl -s https://api.wordpress.org/secret-key/1.1/salt/ > /tmp/wp.salts || true
sed -i "/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d" /var/www/html/wp-config.php || true
if [ -s /tmp/wp.salts ]; then
  sed -i "/Happy publishing\./r /tmp/wp.salts" /var/www/html/wp-config.php || true
fi
cat >/tmp/wp.extra <<EOF
define('FS_METHOD', 'direct');
define('FTP_HOST', 'localhost');
define('FTP_USER', '${SFTP_USER}');
define('FTP_PASS', '${SFTP_PASSWORD}');
EOF
sed -i "/Happy publishing\./r /tmp/wp.extra" /var/www/html/wp-config.php || true

# Ensure /tmp is world-writable with sticky bit
chmod 1777 /tmp

# Set correct permissions for WordPress
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Ensure persistent mount
if ! grep -q " /var/www/html nfs4 " /etc/fstab; then
  echo "${MOUNT_TARGET}:/ /var/www/html nfs4 defaults,_netdev 0 0" >> /etc/fstab
fi
mount -a
mount | grep /var/www/html

echo "Step: configure MySQL"
mysql -u root <<-EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "Step: Apache vhost tweaks and restart"
echo "<Directory /var/www/html/>" | tee -a /etc/apache2/sites-available/000-default.conf
  echo "    DirectoryIndex index.php index.html" | tee -a /etc/apache2/sites-available/000-default.conf
  echo "</Directory>" | tee -a /etc/apache2/sites-available/000-default.conf
systemctl restart apache2

# Download plugins (non-fatal)
echo "Step: download plugins"
wget -q https://downloads.wordpress.org/plugin/cookie-notice.2.4.8.zip || true
wget -q https://downloads.wordpress.org/plugin/all-in-one-wp-migration.7.75.zip || true
wget -q https://downloads.wordpress.org/plugin/elementor.3.13.4.zip || true
wget -q https://downloads.wordpress.org/plugin/updraftplus.1.23.4.zip || true
wget -q https://downloads.wordpress.org/plugin/wordfence.7.9.3.zip || true
wget -q https://downloads.wordpress.org/plugin/wordpress-importer.0.8.1.zip || true

# Unzip plugins (non-fatal)
echo "Step: install plugins"
for zip in "$TMP"/*.zip; do
  [ -f "$zip" ] || continue
  unzip -o -q "$zip" -d /var/www/html/wp-content/plugins/ || true
done

echo "===== $(date -u +"%Y-%m-%dT%H:%M:%SZ") user_data.sh end ====="