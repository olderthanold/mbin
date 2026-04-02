#!/bin/bash

#exit on error, so that script does not continue wehn things go bad
#and do stuff that can't work
set -e

DOMAIN="olderthanold.duckdns.org"
NGINX_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"
WEB_ROOT="/var/www/$DOMAIN"

# Check if config already exists
if [ -f "$NGINX_AVAILABLE" ]; then
    echo "Config already exists at $NGINX_AVAILABLE. Exiting."
    exit 1
fi

# Create web root
sudo mkdir -p "$WEB_ROOT"
sudo chown -R www-data:www-data "$WEB_ROOT"

# Create Nginx config
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

# Create symlink (enable site)
if [ -e "$NGINX_ENABLED" ]; then
    echo "Symlink or file already exists in sites-enabled: $NGINX_ENABLED"
else
    sudo ln -s "$NGINX_AVAILABLE" "$NGINX_ENABLED"
    echo "Symlink created: $NGINX_ENABLED -> $NGINX_AVAILABLE"
fi

# Test and reload Nginx
sudo nginx -t
sudo systemctl reload nginx

echo "Nginx config created and enabled for $DOMAIN"
echo "Run: sudo certbot --nginx -d $DOMAIN"