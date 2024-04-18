#!/bin/bash

# Init incus
sudo incus admin init --auto

# Launch Instance
sudo incus launch images:debian/bookworm/amd64 tonics-wordpress

# Dependencies
sudo incus exec tonics-wordpress -- bash -c "apt update -y && apt upgrade -y"

sudo incus exec tonics-wordpress -- bash -c "DEBIAN_FRONTEND=noninteractive apt install -y wget php php8.2-fpm php8.2-dom  php8.2-xml php8.2-xmlrpc php8.2-soap php8.2-mysql php8.2-mbstring php8.2-readline php8.2-gd  php8.2-gmp php8.2-bcmath php8.2-zip php8.2-curl php8.2-intl php8.2-apcu"

# Clean Debian Cache
sudo incus exec tonics-wordpress -- bash -c "apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*"

#
# Fetch WordPress, extract and install to the default web root.
#
sudo incus exec tonics-wordpress -- bash -c "wget 'https://wordpress.org/latest.tar.gz' -O wordpress.tar.gz"
sudo incus exec tonics-wordpress -- bash -c "rm -Rf /var/www/html/index.html wordpress"
sudo incus exec tonics-wordpress -- bash -c "tar xvzf wordpress.tar.gz"

# WordPress Version
WordPress_Version=$(grep '$wp_version =' wordpress/wp-includes/version.php | awk -F"'" '{print $2}')

# Create the target directory if it doesn't exist
sudo incus exec tonics-wordpress -- bash -c "mkdir -p /var/www/html/"

sudo incus exec tonics-wordpress -- bash -c "mv wordpress/* /var/www/html/"

# Version
Version="PHP__$(sudo incus exec tonics-wordpress -- php -v | head -n 1 | awk '{print $2}' | cut -d '-' -f 1)__WordPress__$WordPress_Version"

# Publish Image
mkdir images && sudo incus stop tonics-wordpress && sudo incus publish tonics-wordpress --alias tonics-wordpress

# Export Image
sudo incus start tonics-wordpress
sudo incus image export tonics-wordpress images/wordpress-bookworm-$Version

# Image Info
sudo incus image info tonics-wordpress >> images/info.txt
