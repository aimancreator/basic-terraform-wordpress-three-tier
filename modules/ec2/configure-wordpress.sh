#!/bin/bash
set -euo pipefail

# Keep startup diagnostics, without tracing commands or printing credentials.
exec > >(tee -a /var/log/wordpress-install.log) 2>&1

# Retry transient repository/network failures while the new instance starts.
installed=false
for attempt in {1..5}; do
  if dnf install -y httpd php php-fpm php-mysqlnd php-gd php-mbstring php-xml php-intl php-zip python3 tar gzip; then
    installed=true
    break
  fi
  sleep 15
done
if [[ "$installed" != true ]]; then
  echo "WordPress package installation failed."
  exit 1
fi

# Standard Amazon Linux 2023 images include curl, AWS CLI, and SSM Agent.
command -v aws
systemctl enable --now amazon-ssm-agent

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
curl --fail --location --retry 10 --retry-delay 5 --retry-all-errors \
  https://wordpress.org/latest.tar.gz --output "$work_dir/wordpress.tar.gz"
tar -xzf "$work_dir/wordpress.tar.gz" -C "$work_dir"
cp -a "$work_dir/wordpress/." /var/www/html/
chown -R apache:apache /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Retrieve database credentials using the EC2 IAM role.
# Never print credentials to startup logs.
python3 - <<'PY'
import json
import re
import secrets
import subprocess
import time
from pathlib import Path

secret_arn = "${db_secret_arn}"
db_endpoint = "${db_endpoint}"

# Allow time for instance credentials, IAM permissions, and the secret to settle.
for attempt in range(30):
    result = subprocess.run(
        [
            "aws", "secretsmanager", "get-secret-value",
            "--secret-id", secret_arn,
            "--region", "${aws_region}",
            "--query", "SecretString",
            "--output", "text"
        ],
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        credentials = json.loads(result.stdout)
        break
    time.sleep(10)
else:
    raise RuntimeError("Could not retrieve the RDS secret; check IAM and endpoint connectivity")

sample = Path("/var/www/html/wp-config-sample.php")
destination = Path("/var/www/html/wp-config.php")

content = sample.read_text()

def php_string(value):
    return str(value).replace("\\", "\\\\").replace("'", "\\'")

settings = {
    "DB_NAME": credentials.get("dbname") or "wordpress",
    "DB_USER": credentials["username"],
    "DB_PASSWORD": credentials["password"],
    "DB_HOST": db_endpoint,
}

# Generate unique authentication keys locally, without an extra network request.
for key in (
    "AUTH_KEY", "SECURE_AUTH_KEY", "LOGGED_IN_KEY", "NONCE_KEY",
    "AUTH_SALT", "SECURE_AUTH_SALT", "LOGGED_IN_SALT", "NONCE_SALT",
):
    settings[key] = secrets.token_urlsafe(64)

for key, value in settings.items():
    pattern = rf"(define\(\s*'{key}'\s*,\s*)'[^']*'(\s*\);)"
    content, count = re.subn(
        pattern,
        lambda match: match.group(1) + "'" + php_string(value) + "'" + match.group(2),
        content,
        count=1
    )
    if count != 1:
        raise RuntimeError(f"Could not configure {key}")

destination.write_text(content)
destination.chmod(0o640)
PY

chown apache:apache /var/www/html/wp-config.php
systemctl enable --now php-fpm httpd
curl --fail --silent --output /dev/null http://localhost/wp-admin/install.php
touch /var/log/wordpress-install-complete
echo "WordPress installation complete."
