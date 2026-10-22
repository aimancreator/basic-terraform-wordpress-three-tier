
#!/bin/bash
set -euo pipefail

echo "Checking WordPress installation..."

test -f /var/www/html/wp-config-sample.php
test -f /var/www/html/wp-login.php

systemctl is-active --quiet httpd

php --version

echo "WordPress installation checks passed!"
