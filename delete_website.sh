#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# delete_website.sh v02
#
# Purpose:
#   Remove Nginx and Let's Encrypt artifacts created for a domain by web_0_main flow.
#
# Args:
#   $1 domain (optional; default: olderthanold.duckdns.org)
#
# Notes:
#   - Leaves website content directory untouched (default: /webs/<domain>).
#   - Removes domain Nginx site config/symlink and certificate/renewal traces.

DEFAULT_DOMAIN="olderthanold.duckdns.org"
DOMAIN="${1:-$DEFAULT_DOMAIN}"

if [[ "$#" -gt 1 ]]; then
  echo "Usage: $0 [domain]"
  echo "Example: $0"
  echo "Example: $0 example.com"
  exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo).${NC}"
  exit 1
fi

echo -e "${YELLOW}Running delete_website.sh v02${NC}"
echo "Target domain: $DOMAIN"

WEBSITE_DIR="/webs/$DOMAIN"

NGINX_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"
LE_RENEWAL_CONF="/etc/letsencrypt/renewal/$DOMAIN.conf"
LE_LIVE_DIR="/etc/letsencrypt/live/$DOMAIN"
LE_ARCHIVE_DIR="/etc/letsencrypt/archive/$DOMAIN"

echo -e "${YELLOW}[1/4] Removing Nginx site entry for domain...${NC}"
if [[ -L "$NGINX_ENABLED" || -f "$NGINX_ENABLED" ]]; then
  rm -f "$NGINX_ENABLED"
  echo "Removed: $NGINX_ENABLED"
else
  echo -e "${YELLOW}Not found (skip): $NGINX_ENABLED${NC}"
fi

if [[ -f "$NGINX_AVAILABLE" ]]; then
  rm -f "$NGINX_AVAILABLE"
  echo "Removed: $NGINX_AVAILABLE"
else
  echo -e "${YELLOW}Not found (skip): $NGINX_AVAILABLE${NC}"
fi

echo -e "${YELLOW}[2/4] Removing certificate via certbot (if present)...${NC}"
if [[ -f "$LE_RENEWAL_CONF" || -d "$LE_LIVE_DIR" || -d "$LE_ARCHIVE_DIR" ]]; then
  certbot delete --cert-name "$DOMAIN" --non-interactive || true
else
  echo "No certbot-managed certificate artifacts detected for $DOMAIN (skip certbot delete)."
fi

echo -e "${YELLOW}[3/4] Cleaning remaining Let's Encrypt files for domain (if any)...${NC}"
if [[ -f "$LE_RENEWAL_CONF" ]]; then
  rm -f "$LE_RENEWAL_CONF"
  echo "Removed: $LE_RENEWAL_CONF"
fi

if [[ -d "$LE_LIVE_DIR" ]]; then
  rm -rf "$LE_LIVE_DIR"
  echo "Removed: $LE_LIVE_DIR"
fi

if [[ -d "$LE_ARCHIVE_DIR" ]]; then
  rm -rf "$LE_ARCHIVE_DIR"
  echo "Removed: $LE_ARCHIVE_DIR"
fi

# Also remove duplicate lineage traces like <domain>-0001 created by certbot retries.
shopt -s nullglob
for f in /etc/letsencrypt/renewal/"$DOMAIN"-*.conf; do
  rm -f "$f"
  echo "Removed: $f"
done
for d in /etc/letsencrypt/live/"$DOMAIN"-* /etc/letsencrypt/archive/"$DOMAIN"-*; do
  rm -rf "$d"
  echo "Removed: $d"
done
shopt -u nullglob

echo -e "${YELLOW}[4/4] Testing and reloading Nginx...${NC}"
nginx -t
systemctl reload nginx

echo -e "${GREEN}Done. Nginx entry and cert artifacts removed for: $DOMAIN${NC}"
echo "Website content directory intentionally left untouched: $WEBSITE_DIR"
