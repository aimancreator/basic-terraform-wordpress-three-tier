#!/bin/bash
set -euxo pipefail

# Record installation progress
exec > >(tee /var/log/wordpress-install.log) 2>&1

# Install Apache, PHP, and MySQL client libraries
dnf update -y

dnf install -y \
  httpd \
  php \
  php-mysqlnd \
  php-fpm \
  php-gd \
  php-mbstring \
  php-xml \
  php-intl \
  php-zip \
  wget \
  tar

# Download WordPress
cd /tmp
wget -O wordpress.tar.gz \
  https://wordpress.org/latest.tar.gz

# Extract WordPress into Apache web root
tar -xzf wordpress.tar.gz
cp -a wordpress/. /var/www/html/

# Set file ownership and permissions
chown -R apache:apache /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Enable and start Apache
systemctl enable --now httpd




# Write verification script to EC2
cat > /usr/local/bin/verify-wordpress.sh <<'VERIFY_SCRIPT'
${verification_script}
VERIFY_SCRIPT

chmod +x /usr/local/bin/verify-wordpress.sh

# Run verification
/usr/local/bin/verify-wordpress.sh

# Mark installation complete
touch /var/log/wordpress-install-complete
