#!/bin/bash
set -e  # Stop on first error

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# web1_entry_nginx.sh v14
#
# Args:
#   $1 website/domain (required; must contain a dot, e.g. something.cz)
#   $2 web root path (optional)
#      - absolute path (starts with /): used as-is
#      - relative name/path: resolved under /webs/<arg>
#      - omitted: defaults to /webs/<website>
#
# Behavior:
#   1) Resolve domain and web root.
#   2) Auto-heal by removing existing domain nginx entries, then recreate them.
#   3) Write domain nginx site config and enable it.
#   4) Remove default enabled nginx site link to avoid default site taking traffic.
#   5) Validate and reload nginx.

show_help() {
    echo "Usage: $0 <domain> [web_root]"
    echo ""
    echo "Domain rule: must contain '.' (dot)."
    echo "Examples:"
    echo "  $0 something.cz"
    echo "  $0 something.cz /webs/something.cz"
}

validate_domain_arg() {
    local domain="${1:-}"
    [[ -n "$domain" && "$domain" == *.* ]]
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    show_help
    exit 1
fi

DOMAIN="$1"

if ! validate_domain_arg "$DOMAIN"; then
    echo -e "${RED}Error: invalid domain '$DOMAIN' (must contain '.').${NC}"
    show_help
    exit 1
fi

if [ -n "${2:-}" ]; then
    if [[ "$2" == /* ]]; then
        WEB_ROOT="$2"
    else
        WEB_ROOT="/webs/$2"
    fi
else
    WEB_ROOT="/webs/$DOMAIN"
fi

NGINX_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

echo -e "${YELLOW}Running web1_entry_nginx.sh v14${NC}"
echo "Using website/domain: $DOMAIN"
echo "Using web root: $WEB_ROOT"

echo -e "${YELLOW}Autoheal: removing existing Nginx domain entries before recreate...${NC}"
if [ -L "$NGINX_ENABLED" ] || [ -e "$NGINX_ENABLED" ]; then
    sudo rm -f "$NGINX_ENABLED"
    echo "Removed old enabled entry: $NGINX_ENABLED"
else
    echo "Enabled entry not present (skip): $NGINX_ENABLED"
fi

if [ -f "$NGINX_AVAILABLE" ]; then
    sudo rm -f "$NGINX_AVAILABLE"
    echo "Removed old available config: $NGINX_AVAILABLE"
else
    echo "Available config not present (skip): $NGINX_AVAILABLE"
fi

# Write Nginx site config
sudo tee "$NGINX_AVAILABLE" > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    root $WEB_ROOT;
    index index.html index.htm;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

sudo ln -s "$NGINX_AVAILABLE" "$NGINX_ENABLED"  # Enable site
echo "Symlink created: $NGINX_ENABLED -> $NGINX_AVAILABLE"

DEFAULT_ENABLED="/etc/nginx/sites-enabled/default"
if [ -e "$DEFAULT_ENABLED" ]; then
    # Remove default site symlink so domain site takes precedence.
    sudo rm -f "$DEFAULT_ENABLED"
    echo "Removed default enabled site link: $DEFAULT_ENABLED"
else
    echo "Default enabled site link not present: $DEFAULT_ENABLED"
fi

sudo nginx -t  # Validate config
sudo systemctl reload nginx  # Reload service

echo "Nginx config created and enabled for $DOMAIN"
echo "Run: sudo certbot --nginx -d $DOMAIN"