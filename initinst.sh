#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures

# Server/instance-level initialization.
# Scope: host-wide configuration (packages, SSH daemon, firewall/network/web service).

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "Error: required script not found: $f"
    exit 1
  fi
}

for f in \
  "$SCRIPT_DIR/update_inst.sh" \
  "$SCRIPT_DIR/ssh_passwd_auth.sh" \
  "$SCRIPT_DIR/paaswordles_sudo.sh" \
  "$SCRIPT_DIR/global_path_profile.sh" \
  "$SCRIPT_DIR/network_iptables.sh" \
  "$SCRIPT_DIR/network_connect.sh"; do
  require_file "$f"
done

if [[ "$EUID" -ne 0 ]]; then
  echo "Error: run as root (use sudo), e.g.:"
  echo "  sudo bash $0"
  exit 1
fi

echo "1. Running initinst.sh v11 (instance/server setup)"

echo "_________________________________________________________________________"
echo "1.[1/6] update_inst.sh v03 - update apt packages and install base tools (mc)"
bash "$SCRIPT_DIR/update_inst.sh"

echo "_________________________________________________________________________"
echo "1.[2/6] ssh_passwd_auth.sh v04 - enable SSH password + keyboard-interactive auth (PAM)"
bash "$SCRIPT_DIR/ssh_passwd_auth.sh"

echo "_________________________________________________________________________"
echo "1.[3/6] paaswordles_sudo.sh v01 - ensure %sudo has NOPASSWD rule"
bash "$SCRIPT_DIR/paaswordles_sudo.sh"

echo "_________________________________________________________________________"
echo "1.[4/6] global_path_profile.sh v04 - normalize root PATH intelligently + reuse sudoers drop-in"
bash "$SCRIPT_DIR/global_path_profile.sh"

echo "_________________________________________________________________________"
echo "1.[5/6] network_iptables.sh v01 - configure iptables firewall and persistence"
bash "$SCRIPT_DIR/network_iptables.sh"

echo "_________________________________________________________________________"
echo "1.[6/6] network_connect.sh v01 - run nginx and connectivity checks"
bash "$SCRIPT_DIR/network_connect.sh"

echo ""
echo "initinst complete. Host-level setup finished."
echo "Safe to run again (idempotent where possible)."
