#!/bin/bash
set -e  # Stop on first error

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# web1_entry_nginx.sh v18
#
# Args:
#   $1 website/domain (required; must contain a dot, e.g. something.cz)
#   $2 web root path (optional)
#      - absolute path (starts with /): used as-is
#      - relative name/path: resolved under /m web base + <arg>
#      - omitted: defaults to /m web base + <website>
#
# Behavior:
#   1) Resolve domain and web root.
#   2) Auto-heal by removing existing domain nginx entries, then recreate them.
#   3) Write domain nginx site config and enable it.
#      - before certificate exists: HTTP-only block for certbot matching
#      - after certificate exists: HTTP redirect + HTTPS block
#      - /_pages/ exposes a JSON autoindex listing for the current web root
#   4) Remove default enabled nginx site link to avoid default site taking traffic.
#   5) Reload systemd manager config, validate nginx config, and reload nginx.

show_help() {
    local web_base_name="webs"
    local web_base_dir="${WEB_BASE_DIR:-/m/${web_base_name}}"
    echo "Usage: $0 <domain> [web_root]"
    echo ""
    echo "Domain rule: must contain '.' (dot)."
    echo "Examples:"
    echo "  $0 something.cz"
    echo "  $0 something.cz $web_base_dir/something.cz"
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
WEB_BASE_NAME="webs"
WEB_BASE_DIR="${WEB_BASE_DIR:-/m/${WEB_BASE_NAME}}"

if ! validate_domain_arg "$DOMAIN"; then
    echo -e "${RED}Error: invalid domain '$DOMAIN' (must contain '.').${NC}"
    show_help
    exit 1
fi

if [ -n "${2:-}" ]; then
    if [[ "$2" == /* ]]; then
        WEB_ROOT="$2"
    else
        WEB_ROOT="$WEB_BASE_DIR/$2"
    fi
else
    WEB_ROOT="$WEB_BASE_DIR/$DOMAIN"
fi

NGINX_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"
CERT_FULLCHAIN="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
CERT_PRIVKEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"

echo -e "${YELLOW}Running web1_entry_nginx.sh v18${NC}"
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

if [[ -f "$CERT_FULLCHAIN" && -f "$CERT_PRIVKEY" ]]; then
    echo "Certificate found. Writing final HTTP redirect + HTTPS Nginx config."
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

    location ^~ /_pages/ {
        alias $WEB_ROOT/;
        index __mbin_no_index__;
        autoindex on;
        autoindex_format json;
        add_header Cache-Control "no-store";
    }

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
else
    echo "Certificate not found. Writing HTTP-only Nginx config for certbot bootstrap."
    sudo tee "$NGINX_AVAILABLE" > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    root $WEB_ROOT;
    index index.html index.htm;

    location /.well-known/acme-challenge/ {
        root $WEB_ROOT;
    }

    location ^~ /_pages/ {
        alias $WEB_ROOT/;
        index __mbin_no_index__;
        autoindex on;
        autoindex_format json;
        add_header Cache-Control "no-store";
    }

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
fi

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

sudo systemctl daemon-reload  # Refresh unit metadata before reloading nginx.
sudo nginx -t  # Validate config
sudo systemctl reload nginx  # Reload service

echo "Nginx config created and enabled for $DOMAIN"
echo "Run: sudo certbot --nginx -d $DOMAIN"
