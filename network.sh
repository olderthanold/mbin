#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures
#e
###############################################################################
# Network setup and checks (standalone)
# Safe to re-run: package checks and firewall rules are applied idempotently.
###############################################################################

echo ""
echo "[1/4] Installing Nginx web server..."

# Check if nginx is already installed
if dpkg -s nginx >/dev/null 2>&1; then
    echo "✓ Nginx package already installed - skipping installation"
    # Ensure service is enabled and started if present
    sudo systemctl enable --now nginx >/dev/null 2>&1 || true  # Ensure nginx running
else
    # Install nginx for web connectivity verification
    # Nginx will auto-start on installation
    echo "Installing Nginx..."
    sudo apt-get install -y nginx  # Install nginx
    echo "✓ Nginx installed successfully"
fi

###############################################################################
# SECTION 2: Configure iptables Firewall Rules
###############################################################################
echo ""
echo "[2/4] Configuring firewall rules (iptables)..."

echo ""
echo "=== CURRENT INPUT CHAIN ==="
sudo iptables -L INPUT --line-numbers -v

echo ""
echo "Setting up INPUT rules..."

sudo iptables -F INPUT  # Flush INPUT chain

# === INPUT CHAIN CONFIGURATION (inbound) ===
sudo iptables -I INPUT 1 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I INPUT 2 -p icmp -j ACCEPT
sudo iptables -I INPUT 3 -i lo -j ACCEPT
sudo iptables -I INPUT 4 -p tcp --dport 22 -m state --state NEW -j ACCEPT
sudo iptables -I INPUT 5 -p tcp --dport 443 -m state --state NEW -j ACCEPT
sudo iptables -I INPUT 6 -p tcp --dport 80 -m state --state NEW -j ACCEPT
sudo iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited

echo "✓ INPUT firewall rules configured (SSH, HTTP, HTTPS allowed)"

echo ""
echo "=== CURRENT OUTPUT CHAIN ==="
sudo iptables -L OUTPUT --line-numbers -v

echo ""
echo "Configuring OUTPUT rules..."

# === OUTPUT CHAIN CONFIGURATION (outbound) ===
sudo iptables -F OUTPUT  # Flush OUTPUT chain

sudo iptables -P OUTPUT ACCEPT  # Allow outbound traffic

echo "✓ OUTPUT firewall rules configured (all outgoing allowed)"

echo ""
echo "=== FINAL INPUT CHAIN ==="
sudo iptables -L INPUT -v --line-numbers

echo ""
echo "=== FINAL OUTPUT CHAIN ==="
sudo iptables -L OUTPUT -v --line-numbers

echo ""
echo "Saving iptables rules for persistence on reboot..."

if dpkg -l | grep -q iptables-persistent; then
    echo "✓ iptables-persistent already installed"
else
    echo "Installing iptables-persistent (non-interactive mode)..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
fi

sudo netfilter-persistent save  # Save firewall rules
echo "✓ Iptables rules saved permanently"

###############################################################################
# SECTION 3: Test Outbound Connectivity
###############################################################################
echo ""
echo "[3/4] Testing outbound connectivity..."
echo ""

echo "Testing DNS resolution..."
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo "✓ Outbound connectivity working (can reach Google DNS 8.8.8.8)"
else
    echo "⚠ Cannot reach Google DNS 8.8.8.8 - checking network..."
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
# SECTION 4: Test HTTP and HTTPS Ports
###############################################################################

fix_http_nginx() {
    echo "Checking Nginx for HTTP/80..."
    if ! dpkg -s nginx >/dev/null 2>&1; then
        echo "⚠ Nginx is not installed"
        return 1
    fi

    sudo systemctl enable --now nginx >/dev/null 2>&1 || true

    # Ensure default site is enabled when present
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

    echo "⚠ Nginx config test failed for HTTP path"
    return 1
}

fix_https_nginx() {
    echo "Checking Nginx for HTTPS/443..."
    if ! dpkg -s nginx >/dev/null 2>&1; then
        echo "⚠ Nginx is not installed"
        return 1
    fi

    sudo systemctl enable --now nginx >/dev/null 2>&1 || true

    # Ensure default site is enabled when present
    if [ -f /etc/nginx/sites-available/default ] && [ ! -e /etc/nginx/sites-enabled/default ]; then
        sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default 2>/dev/null || true
    fi

    # If default HTTPS lines are commented, uncomment them.
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

    # First validation attempt
    if sudo nginx -t >/dev/null 2>&1; then
        sudo systemctl restart nginx >/dev/null 2>&1 || true
        return 0
    fi

    # If validation fails, try creating test snakeoil cert and retry.
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
echo "[4/4] Testing HTTP and HTTPS ports (80, 443)..."
echo ""

HTTP_REACHABLE=false
HTTPS_REACHABLE=false

if [ -n "$FINAL_PUBLIC_IP" ]; then
    # Test HTTP on port 80 (non-blocking - don't fail if timeout)
    echo "Testing HTTP (port 80)..."
    if timeout 5 curl -s -o /dev/null -w "%{http_code}" http://$FINAL_PUBLIC_IP 2>/dev/null | grep -q "200\|301\|302\|404"; then
        echo "✓ HTTP (port 80) is reachable"
        HTTP_REACHABLE=true
    else
        echo "⚠ HTTP (port 80) not responding - checking/fixing Nginx if configured"
        if fix_http_nginx; then
            if timeout 5 curl -s -o /dev/null -w "%{http_code}" http://$FINAL_PUBLIC_IP 2>/dev/null | grep -q "200\|301\|302\|404"; then
                echo "✓ HTTP (port 80) reachable after Nginx fix"
                HTTP_REACHABLE=true
            else
                echo "⚠ HTTP still not reachable - may need OCI Security Group rules"
            fi
        fi
    fi || true

    # Test HTTPS on port 443 (non-blocking - don't fail if timeout)
    echo ""
    echo "Testing HTTPS (port 443)..."
    if timeout 5 curl -k -s -o /dev/null -w "%{http_code}" https://$FINAL_PUBLIC_IP 2>/dev/null | grep -q "200\|301\|302\|404"; then
        echo "✓ HTTPS (port 443) is reachable"
        HTTPS_REACHABLE=true
    else
        echo "⚠ HTTPS (port 443) not responding - checking/fixing Nginx if configured"
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
echo "=========================================="
echo "✓ NETWORK SETUP & CHECK COMPLETE"
echo "=========================================="
echo "Incoming firewall rules configured: SSH(22), HTTP(80), HTTPS(443)"
if [ -n "$FINAL_PUBLIC_IP" ]; then
    echo "Public IP: $FINAL_PUBLIC_IP"
    echo "HTTP reachability: $HTTP_REACHABLE"
    echo "HTTPS reachability: $HTTPS_REACHABLE"
fi