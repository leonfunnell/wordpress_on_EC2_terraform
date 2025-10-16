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

# Determine target for EFS mount (prefer DNS, fallback to IP if DNS doesn't resolve)
MOUNT_TARGET="$EFS_DNSNAME"
for i in {1..36}; do # wait up to 3 minutes for DNS
  if getent hosts "$EFS_DNSNAME" >/dev/null 2>&1; then
    break
  fi
  echo "Waiting for EFS DNS to resolve..."
  sleep 5
  if [ $i -eq 36 ] && [ -n "$EFS_IP" ]; then
    echo "EFS DNS still not resolvable; falling back to mount target IP $EFS_IP"
    MOUNT_TARGET="$EFS_IP"
  fi
done

# Ensure mount point exists before mounting
mkdir -p /var/www/html

# Retry EFS mount up to 10 times
for i in {1..10}; do
  mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${MOUNT_TARGET}:/  /var/www/html && break
  echo "Retrying EFS mount..."
  sleep 6
  # If first attempts used DNS and it's not resolving, switch to IP if available
  if [ "$MOUNT_TARGET" = "$EFS_DNSNAME" ] && ! getent hosts "$EFS_DNSNAME" >/dev/null 2>&1 && [ -n "$EFS_IP" ]; then
    echo "Switching to EFS mount target IP $EFS_IP"
    MOUNT_TARGET="$EFS_IP"
  fi
done

mount | grep /var/www/html || { echo "EFS mount failed"; exit 1; }

echo -e ${RED}installing apache2 mysql-server php libapache2-mod-php php-mysql vsftpd unzip php-xml php-curl
apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -yq install apache2 mysql-server php libapache2-mod-php php-mysql vsftpd unzip php-xml php-curl curl

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -o /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install

# Set correct permissions for WordPress
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Ensure /tmp is world-writable with sticky bit
chmod 1777 /tmp

# Generate wp-config.php safely using sample + official salts
if [ ! -f /var/www/html/wp-config.php ]; then
  if [ -f /var/www/html/wp-config-sample.php ]; then
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
  else
    # Minimal base if sample missing
    cat >/var/www/html/wp-config.php <<'PHP'
<?php
/* Auto-generated */
PHP
  fi

  # Fill DB credentials
  sed -i "s/database_name_here/${DB_NAME}/" /var/www/html/wp-config.php
  sed -i "s/username_here/${DB_USER}/" /var/www/html/wp-config.php
  sed -i "s/password_here/${DB_PASSWORD}/" /var/www/html/wp-config.php

  # Ensure FS_METHOD and FTP creds exist (before the stop-editing line)
  awk '
    BEGIN{inserted=0}
    /\* That\'s all, stop editing!/ && !inserted {
      print "define(\'FS_METHOD\', \'direct\');";
      print "define(\'FTP_HOST\', \'localhost\');";
      print "define(\'FTP_USER\', \'" ENVIRON["SFTP_USER"] "\');";
      print "define(\'FTP_PASS\', \'" ENVIRON["SFTP_PASSWORD"] "\');";
      inserted=1
    }
    {print}
  ' /var/www/html/wp-config.php > /var/www/html/wp-config.php.tmp && mv /var/www/html/wp-config.php.tmp /var/www/html/wp-config.php

  # Replace the default salt block with fresh salts from WordPress.org
  sed -i "/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d" /var/www/html/wp-config.php
  awk '
    /\* That\'s all, stop editing!/ && !done {
      system("curl -s https://api.wordpress.org/secret-key/1.1/salt/")
      done=1
    }
    {print}
  ' /var/www/html/wp-config.php > /var/www/html/wp-config.php.tmp && mv /var/www/html/wp-config.php.tmp /var/www/html/wp-config.php

  # If minimal base, finish required bits
  if ! grep -q "ABSPATH" /var/www/html/wp-config.php; then
    cat >>/var/www/html/wp-config.php <<'PHP'
$table_prefix  = 'wp_';
define('WP_DEBUG', false);
if ( !defined('ABSPATH') )
  define('ABSPATH', __DIR__ . '/');
require_once(ABSPATH . 'wp-settings.php');
PHP
  fi
fi

# Mount NFS in fstab
echo -e ${RED}mounting NFS:
echo "${MOUNT_TARGET}:/ /var/www/html nfs4 defaults,_netdev 0 0" >> /etc/fstab
mount -a
echo -e ${RED}result of mount NFS:
mount | grep /var/www/html && echo -e ${RED}NFS Mounted successfully!

# Configure MySQL
echo -e ${RED}Configure MySQL...
mysql -u root <<-EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "<Directory /var/www/html/>" | tee -a /etc/apache2/sites-available/000-default.conf
echo "    DirectoryIndex index.php index.html" | tee -a /etc/apache2/sites-available/000-default.conf
echo "</Directory>" | tee -a /etc/apache2/sites-available/000-default.conf

# Ensure rewrite module
a2enmod rewrite || true
systemctl restart apache2

# Install WordPress core files if not present
if [ ! -f /var/www/html/wp-settings.php ]; then
  echo -e ${RED}Install WordPress...
  wget -q -c http://wordpress.org/latest.tar.gz
  tar -xzf latest.tar.gz
  rsync -a wordpress/ /var/www/html/
fi

# Download plugins to $TMP
wget -q https://downloads.wordpress.org/plugin/cookie-notice.2.4.8.zip
wget -q https://downloads.wordpress.org/plugin/all-in-one-wp-migration.7.75.zip 
wget -q https://downloads.wordpress.org/plugin/elementor.3.13.4.zip
wget -q https://downloads.wordpress.org/plugin/updraftplus.1.23.4.zip
wget -q https://downloads.wordpress.org/plugin/wordfence.7.9.3.zip
wget -q https://downloads.wordpress.org/plugin/wordpress-importer.0.8.1.zip

# Unzip plugins into the plugins directory
for zip in $TMP/*.zip; do
  unzip -o -q "$zip" -d /var/www/html/wp-content/plugins/
done
