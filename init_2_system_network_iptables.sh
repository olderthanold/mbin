#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

###############################################################################
# Network firewall setup (iptables + persistence).
# Safe to re-run: rules are rebuilt deterministically.
###############################################################################

echo ""
echo -e "${YELLOW}Running init_2_system_network_iptables.sh v01${NC}"
echo -e "${YELLOW}Configuring iptables firewall and persistence...${NC}"

# Install package with retry when apt/dpkg frontend lock is temporarily held.
apt_install_with_lock_retry() {
    local package="$1"
    local attempts=30
    local sleep_seconds=2
    local i

    for ((i=1; i<=attempts; i++)); do
        if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"; then
            return 0
        fi

        echo "⚠ apt lock or transient apt error while installing '$package' (attempt $i/$attempts)."

        if (( i < attempts )); then
            echo "  Waiting ${sleep_seconds}s and retrying..."
            sleep "$sleep_seconds"
        fi
    done

    return 1
}

echo ""
echo -e "${YELLOW}=== CURRENT INPUT CHAIN ===${NC}"
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
echo -e "${YELLOW}=== CURRENT OUTPUT CHAIN ===${NC}"
sudo iptables -L OUTPUT --line-numbers -v

echo ""
echo -e "${YELLOW}Configuring OUTPUT rules...${NC}"

# === OUTPUT CHAIN CONFIGURATION (outbound) ===
sudo iptables -F OUTPUT  # Flush OUTPUT chain
sudo iptables -P OUTPUT ACCEPT  # Allow outbound traffic

echo "✓ OUTPUT firewall rules configured (all outgoing allowed)"

echo ""
echo -e "${YELLOW}=== FINAL INPUT CHAIN ===${NC}"
sudo iptables -L INPUT -v --line-numbers

echo ""
echo -e "${YELLOW}=== FINAL OUTPUT CHAIN ===${NC}"
sudo iptables -L OUTPUT -v --line-numbers

echo ""
echo "Saving iptables rules for persistence on reboot..."

if dpkg -l | grep -q iptables-persistent; then
    echo "✓ iptables-persistent already installed"
else
    echo "Installing iptables-persistent (with lock retry)..."
    if apt_install_with_lock_retry iptables-persistent; then
        echo "✓ iptables-persistent installed successfully"
    else
        echo -e "${YELLOW}⚠ Failed to install iptables-persistent after retries (apt lock may still be active).${NC}"
        echo -e "${YELLOW}  Skipping persistent save for now; re-run later when apt is free.${NC}"
        exit 0
    fi
fi

sudo netfilter-persistent save
echo "✓ Iptables rules saved permanently"
