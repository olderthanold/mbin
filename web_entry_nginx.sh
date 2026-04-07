#!/bin/bash
set -e  # Stop on first error

# web_entry_nginx.sh v03
#
# Args:
#   $1 website/domain (optional; default: olderthanold.duckdns.org)
#   $2 web root path (optional; default: /webs/<website>)

DOMAIN="${1:-olderthanold.duckdns.org}"

if [ -n "${2:-}" ]; then
    WEB_ROOT="$2"
else
    WEB_ROOT="/webs/$DOMAIN"
fi

NGINX_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

echo "Using website/domain: $DOMAIN"
echo "Using web root: $WEB_ROOT"
echo "Running web_entry_nginx.sh v03"

if [ -f "$NGINX_AVAILABLE" ]; then
    echo "Config already exists at $NGINX_AVAILABLE. Exiting."
    exit 1
fi

sudo mkdir -p "$WEB_ROOT"  # Create web root
sudo chown -R www-data:www-data "$WEB_ROOT"  # Set web ownership

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

sudo nginx -t  # Validate config
sudo systemctl reload nginx  # Reload service

echo "Nginx config created and enabled for $DOMAIN"
echo "Run: sudo certbot --nginx -d $DOMAIN"