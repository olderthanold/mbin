#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Server/instance-level initialization.
# Scope: host-wide configuration (packages, SSH daemon, firewall/network/web service).

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo -e "${RED}Error: required script not found: $f${NC}"
    exit 1
  fi
}

for f in \
  "$SCRIPT_DIR/ini2sys_update_inst.sh" \
  "$SCRIPT_DIR/ini2sys_swap.sh" \
  "$SCRIPT_DIR/ini2sys_ssh_passwd_auth.sh" \
  "$SCRIPT_DIR/ini2sys_paaswordles_sudo.sh" \
  "$SCRIPT_DIR/ini2sys_global_path_profile.sh" \
  "$SCRIPT_DIR/ini2sys_network_iptables.sh" \
  "$SCRIPT_DIR/ini2sys_network_connect.sh"; do
  require_file "$f"
done

if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo), e.g.:${NC}"
  echo "  sudo bash $0"
  exit 1
fi

echo -e "${YELLOW}1. Running ini1sys_.sh v12 (instance/server setup)${NC}"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[1/7] ini2sys_update_inst.sh v05 - update apt packages and install base tools (mc)"
bash "$SCRIPT_DIR/ini2sys_update_inst.sh"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[2/7] ini2sys_swap.sh v02 - create/enable 5G swap and persist in fstab"
bash "$SCRIPT_DIR/ini2sys_swap.sh"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[3/7] ini2sys_ssh_passwd_auth.sh v05 - enable SSH password + keyboard-interactive auth (PAM)"
bash "$SCRIPT_DIR/ini2sys_ssh_passwd_auth.sh"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[4/7] ini2sys_paaswordles_sudo.sh v02 - ensure %sudo has NOPASSWD rule"
bash "$SCRIPT_DIR/ini2sys_paaswordles_sudo.sh"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[5/7] ini2sys_global_path_profile.sh v05 - normalize root PATH intelligently + reuse sudoers drop-in"
bash "$SCRIPT_DIR/ini2sys_global_path_profile.sh"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[6/7] ini2sys_network_iptables.sh v02 - configure iptables firewall and persistence"
bash "$SCRIPT_DIR/ini2sys_network_iptables.sh"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[7/7] ini2sys_network_connect.sh v02 - run nginx and connectivity checks"
bash "$SCRIPT_DIR/ini2sys_network_connect.sh"

echo ""
echo -e "${GREEN}ini1sys_ complete. Host-level setup finished.${NC}"
echo "Safe to run again (idempotent where possible)."
