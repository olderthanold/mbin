#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Server/instance-level initialization.
# Scope: host-wide configuration (packages, SSH daemon, firewall/network/web service).

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INITI_DIR="$SCRIPT_DIR/initi"

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo -e "${RED}Error: required script not found: $f${NC}"
    exit 1
  fi
}

get_script_version() {
  local script_path="$1"
  local v
  v="$(grep -Eom1 '^# [[:alnum:]_.-]+ v[0-9]+|Running [[:alnum:]_.-]+ v[0-9]+' "$script_path" | grep -Eo 'v[0-9]+' | head -n1 || true)"
  echo "$v"
}

S_UPDATE="$INITI_DIR/ini2sys_update_inst.sh"
S_SWAP="$INITI_DIR/ini2sys_swap.sh"
S_SSH="$INITI_DIR/ini2sys_ssh_passwd_auth.sh"
S_SUDO="$INITI_DIR/ini2sys_paaswordles_sudo.sh"
S_PATH="$INITI_DIR/ini2sys_global_path_profile.sh"
S_IPT="$INITI_DIR/ini2sys_network_iptables.sh"
S_NET="$INITI_DIR/ini2sys_network_connect.sh"

for f in \
  "$S_UPDATE" \
  "$S_SWAP" \
  "$S_SSH" \
  "$S_SUDO" \
  "$S_PATH" \
  "$S_IPT" \
  "$S_NET"; do
  require_file "$f"
done

V_UPDATE="$(get_script_version "$S_UPDATE")"
V_SWAP="$(get_script_version "$S_SWAP")"
V_SSH="$(get_script_version "$S_SSH")"
V_SUDO="$(get_script_version "$S_SUDO")"
V_PATH="$(get_script_version "$S_PATH")"
V_IPT="$(get_script_version "$S_IPT")"
V_NET="$(get_script_version "$S_NET")"

if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo), e.g.:${NC}"
  echo "  sudo bash $0"
  exit 1
fi

echo -e "${YELLOW}1. Running ini1sys.sh v14 (instance/server setup)${NC}"
echo "Resolved initi script base path: $INITI_DIR"
echo "Resolved child scripts and versions:"
echo "  - $S_UPDATE ${V_UPDATE:-<unknown>}"
echo "  - $S_SWAP ${V_SWAP:-<unknown>}"
echo "  - $S_SSH ${V_SSH:-<unknown>}"
echo "  - $S_SUDO ${V_SUDO:-<unknown>}"
echo "  - $S_PATH ${V_PATH:-<unknown>}"
echo "  - $S_IPT ${V_IPT:-<unknown>}"
echo "  - $S_NET ${V_NET:-<unknown>}"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[1/7] ini2sys_update_inst.sh ${V_UPDATE:-<unknown>} - update apt packages and install base tools (mc)"
bash "$S_UPDATE"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[2/7] ini2sys_swap.sh ${V_SWAP:-<unknown>} - create/enable 5G swap and persist in fstab"
bash "$S_SWAP"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[3/7] ini2sys_ssh_passwd_auth.sh ${V_SSH:-<unknown>} - enable SSH password + keyboard-interactive auth (PAM)"
bash "$S_SSH"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[4/7] ini2sys_paaswordles_sudo.sh ${V_SUDO:-<unknown>} - ensure %sudo has NOPASSWD rule"
bash "$S_SUDO"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[5/7] ini2sys_global_path_profile.sh ${V_PATH:-<unknown>} - normalize root PATH intelligently + reuse sudoers drop-in"
bash "$S_PATH"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[6/7] ini2sys_network_iptables.sh ${V_IPT:-<unknown>} - configure iptables firewall and persistence"
bash "$S_IPT"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
echo "1.[7/7] ini2sys_network_connect.sh ${V_NET:-<unknown>} - run nginx and connectivity checks"
bash "$S_NET"

echo ""
echo -e "${GREEN}ini1sys complete. Host-level setup finished.${NC}"
echo "Safe to run again (idempotent where possible)."
