#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

###############################################################################
# Network firewall setup (hybrid iptables + UFW persistence).
# Safe to re-run: managed iptables rules are de-duplicated and UFW rules are idempotent.
###############################################################################

echo ""
echo -e "${YELLOW}Running ini2sys_network_iptables.sh v03${NC}"
echo -e "${YELLOW}Configuring hybrid iptables + UFW firewall and persistence...${NC}"

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

        echo "WARN: apt lock or transient apt error while installing '$package' (attempt $i/$attempts)."

        if (( i < attempts )); then
            echo "  Waiting ${sleep_seconds}s and retrying..."
            sleep "$sleep_seconds"
        fi
    done

    return 1
}

ensure_package_installed() {
    local package="$1"
    local required="${2:-true}"

    if dpkg -s "$package" >/dev/null 2>&1; then
        echo "OK: $package already installed"
        return 0
    fi

    echo "Installing $package (with lock retry)..."
    if apt_install_with_lock_retry "$package"; then
        echo "OK: $package installed successfully"
        return 0
    fi

    if [[ "$required" == "true" ]]; then
        echo -e "${RED}ERROR: Failed to install required package '$package' after retries.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}WARN: Failed to install optional package '$package' after retries.${NC}"
    return 1
}

delete_iptables_rule_all() {
    local chain="$1"
    shift

    while sudo iptables -C "$chain" "$@" >/dev/null 2>&1; do
        sudo iptables -D "$chain" "$@"
    done
}

remove_managed_input_rules() {
    delete_iptables_rule_all INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    delete_iptables_rule_all INPUT -p icmp -j ACCEPT
    delete_iptables_rule_all INPUT -i lo -j ACCEPT
    delete_iptables_rule_all INPUT -p tcp --dport 22 -m state --state NEW -j ACCEPT
    delete_iptables_rule_all INPUT -p tcp --dport 443 -m state --state NEW -j ACCEPT
    delete_iptables_rule_all INPUT -p tcp --dport 80 -m state --state NEW -j ACCEPT
    delete_iptables_rule_all INPUT -j REJECT --reject-with icmp-host-prohibited
}

echo ""
echo "Checking required firewall packages..."
ensure_package_installed ufw true

echo ""
echo -e "${YELLOW}=== CURRENT INPUT CHAIN ===${NC}"
sudo iptables -L INPUT --line-numbers -v

echo ""
echo "Setting up UFW defaults and allowed services..."
sudo ufw default reject incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo ""
echo "Setting up managed INPUT rules..."
remove_managed_input_rules

# === INPUT CHAIN CONFIGURATION (inbound) ===
sudo iptables -I INPUT 1 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I INPUT 2 -p icmp -j ACCEPT
sudo iptables -I INPUT 3 -i lo -j ACCEPT
sudo iptables -I INPUT 4 -p tcp --dport 22 -m state --state NEW -j ACCEPT
sudo iptables -I INPUT 5 -p tcp --dport 443 -m state --state NEW -j ACCEPT
sudo iptables -I INPUT 6 -p tcp --dport 80 -m state --state NEW -j ACCEPT

echo "OK: INPUT firewall rules configured (SSH, HTTP, HTTPS allowed; remaining inbound traffic handled by UFW)"

echo ""
echo -e "${YELLOW}=== CURRENT OUTPUT CHAIN ===${NC}"
sudo iptables -L OUTPUT --line-numbers -v

echo ""
echo -e "${YELLOW}Configuring OUTPUT policy...${NC}"

# === OUTPUT CHAIN CONFIGURATION (outbound) ===
sudo iptables -P OUTPUT ACCEPT  # Allow outbound traffic

echo "OK: OUTPUT firewall policy configured (all outgoing allowed)"

echo ""
echo -e "${YELLOW}=== FINAL INPUT CHAIN ===${NC}"
sudo iptables -L INPUT -v --line-numbers

echo ""
echo -e "${YELLOW}=== FINAL OUTPUT CHAIN ===${NC}"
sudo iptables -L OUTPUT -v --line-numbers

echo ""
echo -e "${YELLOW}=== UFW STATUS VERBOSE ===${NC}"
sudo ufw status verbose

echo ""
echo -e "${YELLOW}=== UFW STATUS NUMBERED ===${NC}"
sudo ufw status numbered

echo ""
echo "Saving iptables rules for persistence on reboot..."

if ! ensure_package_installed iptables-persistent false; then
    echo -e "${YELLOW}  Skipping persistent save for now; re-run later when apt is free.${NC}"
    exit 0
fi

sudo netfilter-persistent save
echo "OK: Iptables rules saved permanently"
