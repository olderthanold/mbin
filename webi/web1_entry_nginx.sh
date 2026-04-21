#!/bin/bash
set -e  # Stop on first error

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# web1_entry_nginx.sh v11
#
# Args:
#   $1 website/domain (required; must contain a dot, e.g. something.cz)
#   $2 web root path (optional; default: /webs/<website>)
#
# Behavior:
#   1) Resolve domain and web root.
#   2) Create web root only if missing (leave existing directory untouched).
#   3) If web root was newly created, copy nginx default index template into it
#      and personalize heading with username + domain.
#   4) Write domain nginx site config and enable it.
#   5) Remove default enabled nginx site link to avoid default site taking traffic.
#   6) Validate and reload nginx.

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
    WEB_ROOT="$2"
else
    WEB_ROOT="/webs/$DOMAIN"
fi

NGINX_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

echo -e "${YELLOW}Running web1_entry_nginx.sh v11${NC}"
echo "Using website/domain: $DOMAIN"
echo "Using web root: $WEB_ROOT"

CREATED_WEB_ROOT="false"  # Tracks whether this run created WEB_ROOT.
OWNER_USER="${SUDO_USER:-${USER:-$(whoami)}}"
OWNER_GROUP="$(id -gn "$OWNER_USER" 2>/dev/null || echo "$OWNER_USER")"

if [ -f "$NGINX_AVAILABLE" ]; then
    echo -e "${YELLOW}Config already exists at $NGINX_AVAILABLE. Skipping create step (idempotent).${NC}"
    exit 0
fi

if [ -d "$WEB_ROOT" ]; then
    # Existing page directory: keep as-is.
    echo "WEB_ROOT already exists, leaving directory as-is: $WEB_ROOT"
else
    # Missing page directory: create it and mark as newly created.
    sudo mkdir -p "$WEB_ROOT"  # Create web root only if missing
    sudo chown "$OWNER_USER:$OWNER_GROUP" "$WEB_ROOT"
    sudo chmod 755 "$WEB_ROOT"
    echo "Created WEB_ROOT: $WEB_ROOT"
    echo "Assigned owner: $OWNER_USER:$OWNER_GROUP"
    echo "Assigned permissions: rwxr-xr-x"
    CREATED_WEB_ROOT="true"
fi

# Only seed default page content when directory was created by this run.
if [ "$CREATED_WEB_ROOT" = "true" ]; then
    TEMPLATE_HTML="/var/www/html/index.nginx-debian.html"
    TARGET_HTML="$WEB_ROOT/index.htm"
    USERNAME_VALUE="$OWNER_USER"

    if [ -f "$TEMPLATE_HTML" ]; then
        echo "New web root created. Copying default nginx page template..."
        sudo cp "$TEMPLATE_HTML" "$TARGET_HTML"
        # Personalize default heading in copied template.
        sudo sed -i "s|<h1>Welcome to nginx!</h1>|<h1>Welcome to ${USERNAME_VALUE} @ ${DOMAIN} nginx!</h1>|" "$TARGET_HTML"
        sudo chown "$OWNER_USER:$OWNER_GROUP" "$TARGET_HTML"
        sudo chmod 755 "$TARGET_HTML"
        echo "Created customized page: $TARGET_HTML"
        echo "Assigned owner: $OWNER_USER:$OWNER_GROUP"
        echo "Assigned permissions: rwxr-xr-x"
    else
        echo -e "${YELLOW}Template not found (skip copy): $TEMPLATE_HTML${NC}"
    fi
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

if [ -e "$NGINX_ENABLED" ]; then
    echo "Symlink or file already exists in sites-enabled: $NGINX_ENABLED"
else
    sudo ln -s "$NGINX_AVAILABLE" "$NGINX_ENABLED"  # Enable site
    echo "Symlink created: $NGINX_ENABLED -> $NGINX_AVAILABLE"
fi

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