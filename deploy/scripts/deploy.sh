#!/usr/bin/env bash
# Deploys the already-built artifacts on the server (Parts 5 and 6).
# Run from the repository root ON THE SERVER after copying (scp/rsync over SSH):
#   backend/target/enterprise-risk-api.jar  and  frontend/dist/
# Usage: ./deploy/scripts/deploy.sh YOUR-SUBDOMAIN.duckdns.org
set -euo pipefail
DOMAIN="${1:?usage: deploy.sh <your-subdomain.duckdns.org>}"
JAR="backend/target/enterprise-risk-api.jar"
DIST="frontend/dist"
[ -f "$JAR" ]  || { echo "Missing $JAR"; exit 1; }
[ -d "$DIST" ] || { echo "Missing $DIST"; exit 1; }

# --- Backend ---
sudo mkdir -p /opt/enterprise-risk-api
sudo cp "$JAR" /opt/enterprise-risk-api/app.jar
sudo chown -R riskapi:riskapi /opt/enterprise-risk-api
sed "s/YOUR-SUBDOMAIN.duckdns.org/${DOMAIN}/g" deploy/systemd/enterprise-risk-api.service \
  | sudo tee /etc/systemd/system/enterprise-risk-api.service >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable enterprise-risk-api
sudo systemctl restart enterprise-risk-api

# --- Frontend ---
sudo mkdir -p /var/www/enterprise-risk-frontend
sudo rm -rf /var/www/enterprise-risk-frontend/*
sudo cp -r "$DIST"/* /var/www/enterprise-risk-frontend/

# --- Apache (HTTP vhost; certbot adds HTTPS) ---
if [ ! -f /etc/apache2/sites-available/enterprise-risk-le-ssl.conf ]; then
  sed "s/YOUR-SUBDOMAIN.duckdns.org/${DOMAIN}/g" deploy/apache/enterprise-risk.conf \
    | sudo tee /etc/apache2/sites-available/enterprise-risk.conf >/dev/null
  sudo a2ensite enterprise-risk.conf
  sudo a2dissite 000-default.conf || true
  sudo apachectl configtest
  sudo systemctl reload apache2
  echo "Now run: sudo certbot --apache -d ${DOMAIN}"
else
  sudo apachectl configtest && sudo systemctl reload apache2
fi

echo "Waiting for the API to start..."
for _ in $(seq 1 30); do
  curl -fsS http://127.0.0.1:8080/actuator/health && echo && break
  sleep 2
done
