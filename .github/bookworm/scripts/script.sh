#!/bin/bash

# Init incus
sudo incus admin init --auto

# Launch Instance
sudo incus launch images:debian/bookworm/amd64 tonics-wordpress

mariaDBVersion=$1

# Dependencies
sudo incus exec tonics-wordpress -- bash -c "apt update -y && apt upgrade -y && apt install -y apt-transport-https curl"
sudo incus exec tonics-wordpress -- bash -c "curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=$mariaDBVersion"
sudo incus exec tonics-wordpress -- bash -c "DEBIAN_FRONTEND=noninteractive apt update -y && apt install -y mariadb-server nginx wget php php8.2-fpm php8.2-dom  php8.2-xml php8.2-xmlrpc php8.2-soap php8.2-mysql php8.2-mbstring php8.2-readline php8.2-gd  php8.2-gmp php8.2-bcmath php8.2-zip php8.2-curl php8.2-intl php8.2-apcu"

# Setup MariaDB
sudo incus exec tonics-wordpress -- bash -c "mysql --user=root -sf <<EOS
-- set root password
ALTER USER root@localhost IDENTIFIED BY 'tonics_cloud';
DELETE FROM mysql.user WHERE User='';
-- delete remote root capabilities
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
-- drop database 'test'
DROP DATABASE IF EXISTS test;
-- also make sure there are lingering permissions to it
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- make changes immediately
FLUSH PRIVILEGES;
EOS
"

# Start Nginx
sudo incus exec tonics-wordpress -- bash -c "sudo nginx"

# Clean Debian Cache
sudo incus exec tonics-wordpress -- bash -c "apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*"

#
# Fetch WordPress, extract and install to the default web root.
#
sudo incus exec tonics-wordpress -- bash -c "wget 'https://wordpress.org/latest.tar.gz' -O wordpress.tar.gz"
sudo incus exec tonics-wordpress -- bash -c "rm -Rf /var/www/html/index.html wordpress"
sudo incus exec tonics-wordpress -- bash -c "tar xvzf wordpress.tar.gz"

# WordPress Version
WordPress_Version=$(sudo incus exec tonics-wordpress -- grep '$wp_version =' wordpress/wp-includes/version.php | awk -F"'" '{print $2}')

# Create the target directory if it doesn't exist
sudo incus exec tonics-wordpress -- bash -c "mkdir -p /var/www/wordpress/"

sudo incus exec tonics-wordpress -- bash -c "mv wordpress/* /var/www/wordpress/"

# Version
Version="MariaDB__$(sudo incus exec tonics-wordpress -- mysql -V | awk '{print $5}' | sed 's/,//')__Nginx__$(sudo incus exec tonics-wordpress -- nginx -v |& sed 's/nginx version: nginx\///')__PHP__$(sudo incus exec tonics-wordpress -- php -v | head -n 1 | awk '{print $2}' | cut -d '-' -f 1)__WordPress__$WordPress_Version"

# Publish Image
mkdir images && sudo incus stop tonics-wordpress && sudo incus publish tonics-wordpress --alias tonics-wordpress

# Export Image
sudo incus start tonics-wordpress
sudo incus image export tonics-wordpress images/wordpress-bookworm-$Version

# Image Info
sudo incus image info tonics-wordpress >> images/info.txt
