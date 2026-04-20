#!/bin/bash
set -euo pipefail  # Fail on errors/unset vars/pipeline failures

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running init_2_system_update_inst.sh v04${NC}"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[1/6].a apt_update_upgrade v04 - Updating system packages..."
sudo apt-get update  # Refresh package index
sudo apt-get upgrade -y  # Upgrade installed packages
echo "✓ System packages updated successfully"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[1/6].b install_mc v04 - Installing Midnight Commander (mc)..."
echo -e "${YELLOW}Checking installed package list for mc...${NC}"
if apt list --installed 2>/dev/null | grep -q '^mc/'; then
    echo "✓ mc already installed"
else
    echo -e "${YELLOW}mc not found in installed package list. Installing with: sudo apt install -y mc${NC}"
    sudo apt install -y mc
    if apt list --installed 2>/dev/null | grep -q '^mc/'; then
        echo "✓ mc installed"
    else
        echo -e "${RED}Error: mc installation did not complete successfully${NC}"
        exit 1
    fi
fi