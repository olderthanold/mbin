#!/usr/bin/env bash
set -euo pipefail

# web_cert_nginx.sh v02
#
# Purpose:
#   Obtain and configure an auto-renewable Let's Encrypt certificate for Nginx.
#
# Behavior:
#   1) Accept optional domain argument.
#      - If not provided, defaults to olderthanold.duckdns.org ("duck").
#   2) Check whether certificate files already exist for the domain.
#   3) If missing, request/install cert via certbot nginx plugin.
#   4) Test nginx config and test cert renewal flow.
#   5) Enable and start certbot.timer for automatic renewal.

DEFAULT_DOMAIN="olderthanold.duckdns.org"
DOMAIN="${1:-$DEFAULT_DOMAIN}"

if [[ "$#" -gt 1 ]]; then
  echo "Usage: $0 [domain]"
  echo "Example: $0"
  echo "Example: $0 example.com"
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

CERT_FULLCHAIN="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
CERT_PRIVKEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"

echo "Running web_cert_nginx.sh v02"
echo "Target domain: $DOMAIN"
echo "[1/5] Ensuring certbot + nginx plugin are installed (this may take a while)..."
apt-get update -y
apt-get install -y certbot python3-certbot-nginx

echo "[2/5] Checking whether certificate already exists for $DOMAIN..."
if [[ -f "$CERT_FULLCHAIN" && -f "$CERT_PRIVKEY" ]]; then
  echo "Certificate files already exist for $DOMAIN. Skipping issuance."
else
  echo "Certificate not found. Requesting certificate via certbot..."
  certbot --nginx \
    -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    --register-unsafely-without-email \
    --redirect
fi

echo "[3/5] Testing nginx configuration..."
nginx -t

echo "[4/5] Enabling and starting auto-renew timer..."
systemctl enable --now certbot.timer
systemctl is-enabled certbot.timer >/dev/null && echo "certbot.timer is enabled"

echo "[5/5] Testing renewal flow (dry-run)..."
certbot renew --dry-run

echo "Done. Certificate workflow completed for: $DOMAIN"
echo "Tip: check next scheduled run with: systemctl list-timers | grep certbot"
