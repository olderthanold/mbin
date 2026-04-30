#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

###############################################################################
# Network firewall setup (UFW).
# Safe to re-run: UFW rules are idempotent and old legacy INPUT rules are removed.
###############################################################################

echo ""
echo -e "${YELLOW}Running ini2sys_network_iptables.sh v04${NC}"
echo -e "${YELLOW}Configuring UFW firewall...${NC}"

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

    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -qx 'install ok installed'; then
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

is_legacy_input_rule() {
    local rule="$1"

    case "$rule" in
        "-A INPUT -j REJECT --reject-with icmp-host-prohibited")
            return 0
            ;;
        "-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT")
            return 0
            ;;
        "-A INPUT -p icmp -j ACCEPT")
            return 0
            ;;
        "-A INPUT -i lo -j ACCEPT")
            return 0
            ;;
    esac

    if [[ "$rule" == "-A INPUT "* && "$rule" == *"-p tcp"* && "$rule" == *"--state NEW"* && "$rule" == *"-j ACCEPT"* ]]; then
        case "$rule" in
            *"--dport 22"*|*"--dport 80"*|*"--dport 443"*)
                return 0
                ;;
        esac
    fi

    return 1
}

remove_legacy_input_rules() {
    local rule
    local removed=0
    local -a args

    while IFS= read -r rule; do
        if is_legacy_input_rule "$rule"; then
            read -r -a args <<< "${rule#-A }"
            sudo iptables -D "${args[@]}"
            removed=1
        fi
    done < <(sudo iptables -S INPUT)

    if (( removed )); then
        echo "OK: Removed old legacy INPUT rules previously managed outside UFW"
    else
        echo "OK: No old legacy INPUT rules found"
    fi
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
echo "Cleaning old legacy INPUT rules from pre-UFW setup..."
remove_legacy_input_rules

echo "OK: UFW firewall configured (SSH, HTTP, HTTPS allowed; remaining inbound traffic rejected)"

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
echo "OK: UFW rules are persistent across reboot"
