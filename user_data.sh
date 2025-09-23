#!/bin/bash
# must be run as sudo/root

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
apt-get -yq upgrade
echo -e ${RED}running apt-get update...
apt-get -yq update

echo -e ${RED}installing nfs-common...
apt-get -yq install nfs-common

mkdir -p /var/www/html
mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $EFS_DNSNAME:/  /var/www/html
mount | grep /var/www/html
echo -e ${RED}installing apache2 mysql-server php libapache2-mod-php php-mysql vsftpd unzip awscli
apt-get -yq install apache2 mysql-server php libapache2-mod-php php-mysql vsftpd unzip awscli

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

echo -e ${RED}Configure WordPress...
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sed -i "s/database_name_here/$DB_NAME/g" /var/www/html/wp-config.php
sed -i "s/username_here/$DB_USER/g" /var/www/html/wp-config.php
sed -i "s/password_here/$DB_PASSWORD/g" /var/www/html/wp-config.php
chown -R www-data:www-data /var/www/html/

echo -e ${RED}Download WordPress plugins...

wget https://downloads.wordpress.org/plugin/cookie-notice.2.4.8.zip
wget https://downloads.wordpress.org/plugin/all-in-one-wp-migration.7.75.zip 
wget https://downloads.wordpress.org/plugin/elementor.3.13.4.zip
wget https://downloads.wordpress.org/plugin/updraftplus.1.23.4.zip
wget https://downloads.wordpress.org/plugin/wordfence.7.9.3.zip
wget https://downloads.wordpress.org/plugin/wordpress-importer.0.8.1.zip
cd /var/www/html/wp-content/plugins
echo -e ${RED}Unzip plugins...
unzip $TMP/*.zip
