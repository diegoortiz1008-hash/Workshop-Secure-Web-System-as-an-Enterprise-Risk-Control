#!/usr/bin/env bash
# One-time Ubuntu server preparation (Part 4). Run as a sudo-capable, non-root user.
set -euo pipefail

sudo apt update
sudo apt upgrade -y
sudo apt install -y apache2 certbot python3-certbot-apache openjdk-21-jre ufw curl

# Firewall: SSH + HTTP + HTTPS only. Port 8080 stays closed.
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status verbose

# Dedicated system user for the API (no login shell, no home).
id riskapi >/dev/null 2>&1 || sudo useradd --system --no-create-home --shell /usr/sbin/nologin riskapi

# Apache modules for TLS, reverse proxy and SPA routing.
sudo a2enmod ssl proxy proxy_http rewrite headers
sudo systemctl restart apache2

# Automatic security updates.
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -f noninteractive unattended-upgrades
