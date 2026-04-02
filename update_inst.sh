#!/bin/bash
set -o pipefail  # Fail pipeline if any command fails

echo ""
echo "[1/2] apt_update_upgrade v01 - Updating system packages..."
# sudo apt-get update  # Refresh package index
# sudo apt-get upgrade -y  # Upgrade installed packages
# echo "✓ System packages updated successfully"

echo "════════════════════════additional apps═══════════════════════════"
echo "[2/2] install_mc v01 - Installing Midnight Commander (mc)..."
echo "Installing Midnight Commander (mc) silently..."
if dpkg -s mc >/dev/null 2>&1; then
    echo "✓ mc already installed"
else
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mc >/dev/null 2>&1  # Install mc silently
    echo "✓ mc installed"
fi