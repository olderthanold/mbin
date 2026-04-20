#!/bin/bash
set -euo pipefail  # Fail on errors/unset vars/pipeline failures

echo "Running init_2_system_update_inst.sh v04"

echo "_________________________________________________________________________"
echo "1.[1/6].a apt_update_upgrade v04 - Updating system packages..."
sudo apt-get update  # Refresh package index
sudo apt-get upgrade -y  # Upgrade installed packages
echo "✓ System packages updated successfully"

echo "_________________________________________________________________________"
echo "1.[1/6].b install_mc v04 - Installing Midnight Commander (mc)..."
echo "Checking installed package list for mc..."
if apt list --installed 2>/dev/null | grep -q '^mc/'; then
    echo "✓ mc already installed"
else
    echo "mc not found in installed package list. Installing with: sudo apt install -y mc"
    sudo apt install -y mc
    if apt list --installed 2>/dev/null | grep -q '^mc/'; then
        echo "✓ mc installed"
    else
        echo "Error: mc installation did not complete successfully"
        exit 1
    fi
fi