#!/usr/bin/env bash
# Updates the Duck DNS record with this server's current public IP.
# Install:
#   sudo mkdir -p /opt/duckdns
#   sudo cp duckdns-update.sh /opt/duckdns/ && sudo chmod 700 /opt/duckdns/duckdns-update.sh
#   echo "YOUR_DUCKDNS_TOKEN" | sudo tee /opt/duckdns/duckdns.token >/dev/null
#   sudo chmod 600 /opt/duckdns/duckdns.token
#   (sudo crontab -l 2>/dev/null; echo "*/5 * * * * /opt/duckdns/duckdns-update.sh YOUR-SUBDOMAIN") | sudo crontab -
# The token is read from a file so it never appears in the repo, in crontab or in the process list.
set -euo pipefail
SUBDOMAIN="${1:?usage: duckdns-update.sh <subdomain-without-.duckdns.org>}"
TOKEN_FILE="${DUCKDNS_TOKEN_FILE:-/opt/duckdns/duckdns.token}"
TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
RESULT="$(curl -fsS --config - <<< "url = \"https://www.duckdns.org/update?domains=${SUBDOMAIN}&token=${TOKEN}&ip=\"")"
logger -t duckdns "update ${SUBDOMAIN}: ${RESULT}"
[ "$RESULT" = "OK" ]
