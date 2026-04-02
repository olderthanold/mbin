#!/bin/bash

###############################################################################
# OCI Linux Ubuntu Instance Initialization Script
# Purpose: System update, package installation, iptables firewall, connectivity
# Usage: chmod +x init-instance.sh && ./init-instance.sh
# Note: Script is idempotent - safe to run multiple times
###############################################################################

# Exit on critical errors only (not on curl timeouts or network issues)
set -o pipefail

echo "=========================================="
echo "Starting OCI Instance Initialization"
echo "=========================================="

###############################################################################
# SECTION 1: System Update
###############################################################################
echo ""
echo "[1/5] Updating system packages..."
# Refresh package list from repositories
sudo apt-get update
# Upgrade all packages to latest versions (-y = automatic yes to prompts)
sudo apt-get upgrade -y
echo "✓ System packages updated successfully"

echo "════════════════════════additional apps═══════════════════════════"
echo "Installing Midnight Commander (mc) silently..."
if dpkg -s mc >/dev/null 2>&1; then
    echo "✓ mc already installed"
else
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mc >/dev/null 2>&1
    echo "✓ mc installed"
fi