#!/bin/bash
set -o pipefail  # Fail pipeline if any command fails

echo "Running update_inst.sh v03"

echo "_________________________________________________________________________"
echo "1.[1/4].a apt_update_upgrade v03 - Updating system packages..."
# sudo apt-get update  # Refresh package index
# sudo apt-get upgrade -y  # Upgrade installed packages
# echo "✓ System packages updated successfully"

echo "_________________________________________________________________________"
echo "1.[1/4].b install_mc v03 - Installing Midnight Commander (mc)..."
echo "Installing Midnight Commander (mc) silently..."
if dpkg -s mc >/dev/null 2>&1; then
    echo "✓ mc already installed"
else
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mc >/dev/null 2>&1  # Install mc silently
    echo "✓ mc installed"
fi