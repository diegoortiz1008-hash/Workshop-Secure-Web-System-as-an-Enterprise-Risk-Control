#!/usr/bin/env bash
# Part 7 verification checklist. Run from ANY machine (e.g., your laptop).
# Usage: ./deploy/scripts/verify.sh YOUR-SUBDOMAIN.duckdns.org
set -uo pipefail
DOMAIN="${1:?usage: verify.sh <your-subdomain.duckdns.org>}"

echo "== 1. DNS resolution"
getent hosts "$DOMAIN" || dig +short "$DOMAIN"

echo; echo "== 2. Unauthenticated request must return 401"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "https://${DOMAIN}/api/risk-status"

echo; echo "== 3. Invalid token must return 401"
curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "Authorization: Bearer invalid.token.value" \
  "https://${DOMAIN}/api/risk-status"

echo; echo "== 4. HTTP redirects to HTTPS"
curl -s -o /dev/null -w "HTTP %{http_code} -> %{redirect_url}\n" "http://${DOMAIN}/"

echo; echo "== 5. Certificate (issuer, subject, validity)"
echo | openssl s_client -connect "${DOMAIN}:443" -servername "${DOMAIN}" 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates

echo; echo "== 6. Port 8080 must NOT be reachable from the internet"
if timeout 5 bash -c "</dev/tcp/${DOMAIN}/8080" 2>/dev/null; then
  echo "FAIL: port 8080 is open"
else
  echo "OK: port 8080 is closed/filtered"
fi

echo; echo "Run on the server:  sudo certbot renew --dry-run"
echo "Audit logs:         sudo journalctl -u enterprise-risk-api | grep AUDIT"
