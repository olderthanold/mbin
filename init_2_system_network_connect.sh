#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

###############################################################################
# Network checks and web reachability.
# Safe to re-run: validates/repairs nginx defaults where possible.
###############################################################################

echo ""
echo -e "${YELLOW}Running init_2_system_network_connect.sh v01${NC}"
echo -e "${YELLOW}Checking nginx, outbound connectivity, HTTP and HTTPS reachability...${NC}"

echo -e "${YELLOW}network_connect.[1/3] nginx_install_check v01 - Installing/checking Nginx web server...${NC}"

# Check if nginx is already installed
if dpkg -s nginx >/dev/null 2>&1; then
    echo -e "${YELLOW}✓ Nginx package already installed - skipping installation${NC}"
    sudo systemctl enable --now nginx >/dev/null 2>&1 || true
else
    echo "Installing Nginx..."
    sudo apt-get install -y nginx
    echo "✓ Nginx installed successfully"
fi

###############################################################################
# SECTION 2: Test Outbound Connectivity
###############################################################################
echo ""
echo "network_connect.[2/3] outbound_check v01 - Testing outbound connectivity..."
echo ""

echo "Testing DNS resolution..."
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo "✓ Outbound connectivity working (can reach Google DNS 8.8.8.8)"
else
    echo -e "${YELLOW}⚠ Cannot reach Google DNS 8.8.8.8 - checking network...${NC}"
fi || true

echo ""
echo "Network Configuration (Private IP):"
ip -br addr show | grep -v "^lo"

echo ""
echo "Default Route:"
ip route show | grep default

echo ""
echo "DNS Configuration:"
cat /etc/resolv.conf 2>/dev/null || echo "  (No /etc/resolv.conf found)"

echo ""
echo "Testing external connectivity..."
EXTERNAL_REACHABLE=false
if timeout 3 curl -s http://www.google.com -o /dev/null 2>&1; then
    echo "✓ Can reach external website (www.google.com)"
    EXTERNAL_REACHABLE=true
else
    echo "⚠ Cannot reach external website"
fi || true

if [ "$EXTERNAL_REACHABLE" = true ]; then
    echo ""
    echo "Querying public IP from external service..."
    PUBLIC_IP_SERVICE=$(timeout 3 curl -s ifconfig.me 2>/dev/null || dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || echo "")
    if [ -n "$PUBLIC_IP_SERVICE" ]; then
        echo "✓ Public IP from service: $PUBLIC_IP_SERVICE"
        FINAL_PUBLIC_IP=$PUBLIC_IP_SERVICE
    else
        echo "⚠ Could not query public IP service"
        FINAL_PUBLIC_IP=""
    fi
else
    FINAL_PUBLIC_IP=""
fi

###############################################################################
# SECTION 3: Test HTTP and HTTPS Ports
###############################################################################

fix_http_nginx() {
    echo -e "${YELLOW}Checking Nginx for HTTP/80...${NC}"
    if ! dpkg -s nginx >/dev/null 2>&1; then
        echo "⚠ Nginx is not installed"
        return 1
    fi

    sudo systemctl enable --now nginx >/dev/null 2>&1 || true

    if [ -f /etc/nginx/sites-available/default ] && [ ! -e /etc/nginx/sites-enabled/default ]; then
        sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default 2>/dev/null || true
    fi

    if ! grep -Eq "^\s*listen\s+80(\s|;)|^\s*listen\s+\[::\]:80(\s|;)" /etc/nginx/sites-enabled/default 2>/dev/null; then
        echo "⚠ Default Nginx site does not appear to listen on 80"
    fi

    if sudo nginx -t >/dev/null 2>&1; then
        sudo systemctl restart nginx >/dev/null 2>&1 || true
        return 0
    fi

    echo -e "${YELLOW}⚠ Nginx config test failed for HTTP path${NC}"
    return 1
}

fix_https_nginx() {
    echo -e "${YELLOW}Checking Nginx for HTTPS/443...${NC}"
    if ! dpkg -s nginx >/dev/null 2>&1; then
        echo "⚠ Nginx is not installed"
        return 1
    fi

    sudo systemctl enable --now nginx >/dev/null 2>&1 || true

    if [ -f /etc/nginx/sites-available/default ] && [ ! -e /etc/nginx/sites-enabled/default ]; then
        sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default 2>/dev/null || true
    fi

    if [ -f /etc/nginx/sites-available/default ]; then
        if grep -Eq "^\s*#\s*listen\s+443\s+ssl\s+default_server;" /etc/nginx/sites-available/default; then
            echo "Uncommenting HTTPS listen directives in default site..."
            sudo sed -i -E "s|^\s*#\s*listen\s+443\s+ssl\s+default_server;|    listen 443 ssl default_server;|" /etc/nginx/sites-available/default
            sudo sed -i -E "s|^\s*#\s*listen\s+\[::\]:443\s+ssl\s+default_server;|    listen [::]:443 ssl default_server;|" /etc/nginx/sites-available/default

            if [ -f /etc/nginx/snippets/snakeoil.conf ]; then
                sudo sed -i -E "s|^\s*#\s*include\s+snippets/snakeoil.conf;|    include snippets/snakeoil.conf;|" /etc/nginx/sites-available/default
            fi
        fi
    fi

    if sudo nginx -t >/dev/null 2>&1; then
        sudo systemctl restart nginx >/dev/null 2>&1 || true
        return 0
    fi

    if [ ! -f /etc/ssl/certs/ssl-cert-snakeoil.pem ] || [ ! -f /etc/ssl/private/ssl-cert-snakeoil.key ]; then
        echo "HTTPS cert files missing - installing/generating snakeoil cert for testing..."
        sudo apt-get install -y ssl-cert >/dev/null 2>&1 || true
        sudo make-ssl-cert generate-default-snakeoil --force-overwrite >/dev/null 2>&1 || true
    fi

    if sudo nginx -t >/dev/null 2>&1; then
        sudo systemctl restart nginx >/dev/null 2>&1 || true
        return 0
    fi

    echo "⚠ HTTPS fix attempted, but nginx config is still invalid"
    return 1
}

echo ""
echo "network_connect.[3/3] http_https_check v01 - Testing HTTP and HTTPS ports (80, 443)..."
echo ""

HTTP_REACHABLE=false
HTTPS_REACHABLE=false

if [ -n "$FINAL_PUBLIC_IP" ]; then
    echo "Testing HTTP (port 80)..."
    if timeout 5 curl -s -o /dev/null -w "%{http_code}" http://$FINAL_PUBLIC_IP 2>/dev/null | grep -q "200\|301\|302\|404"; then
        echo "✓ HTTP (port 80) is reachable"
        HTTP_REACHABLE=true
    else
        echo -e "${YELLOW}⚠ HTTP (port 80) not responding - checking/fixing Nginx if configured${NC}"
        if fix_http_nginx; then
            if timeout 5 curl -s -o /dev/null -w "%{http_code}" http://$FINAL_PUBLIC_IP 2>/dev/null | grep -q "200\|301\|302\|404"; then
                echo "✓ HTTP (port 80) reachable after Nginx fix"
                HTTP_REACHABLE=true
            else
                echo "⚠ HTTP still not reachable - may need OCI Security Group rules"
            fi
        fi
    fi || true

    echo ""
    echo "Testing HTTPS (port 443)..."
    if timeout 5 curl -k -s -o /dev/null -w "%{http_code}" https://$FINAL_PUBLIC_IP 2>/dev/null | grep -q "200\|301\|302\|404"; then
        echo "✓ HTTPS (port 443) is reachable"
        HTTPS_REACHABLE=true
    else
        echo -e "${YELLOW}⚠ HTTPS (port 443) not responding - checking/fixing Nginx if configured${NC}"
        if fix_https_nginx; then
            if timeout 5 curl -k -s -o /dev/null -w "%{http_code}" https://$FINAL_PUBLIC_IP 2>/dev/null | grep -q "200\|301\|302\|404"; then
                echo "✓ HTTPS (port 443) reachable after Nginx fix"
                HTTPS_REACHABLE=true
            else
                echo "⚠ HTTPS still not reachable - likely external path (OCI SG/NSG/route/LB) or different app issue"
            fi
        fi
    fi || true
else
    echo "⚠ Could not test - no public IP available"
fi

echo ""
echo -e "${GREEN}✓ NETWORK CHECKS COMPLETE${NC}"
if [ -n "$FINAL_PUBLIC_IP" ]; then
    echo "Public IP: $FINAL_PUBLIC_IP"
    echo "HTTP reachability: $HTTP_REACHABLE"
    echo "HTTPS reachability: $HTTPS_REACHABLE"
fi
