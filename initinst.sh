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
  "$SCRIPT_DIR/network.sh" \
  "$SCRIPT_DIR/root_path_bashrc.sh"; do
  require_file "$f"
done

if [[ "$EUID" -ne 0 ]]; then
  echo "Error: run as root (use sudo), e.g.:"
  echo "  sudo bash $0"
  exit 1
fi

echo "1. Running initinst.sh v04 (instance/server setup)"

echo "_________________________________________________________________________"
echo "1.[1/4] update_inst.sh v03 - update apt packages and install base tools (mc)"
bash "$SCRIPT_DIR/update_inst.sh"

echo "_________________________________________________________________________"
echo "1.[2/4] ssh_passwd_auth.sh v02 - enable SSH password + keyboard-interactive auth (PAM)"
bash "$SCRIPT_DIR/ssh_passwd_auth.sh"

echo "_________________________________________________________________________"
echo "1.[3/4] network.sh v02 - configure nginx, firewall rules, and connectivity checks"
bash "$SCRIPT_DIR/network.sh"

echo "_________________________________________________________________________"
echo "1.[4/4] root_path_bashrc.sh v01 - normalize root .bashrc PATH for mbin"
bash "$SCRIPT_DIR/root_path_bashrc.sh"

echo ""
echo "initinst complete. Host-level setup finished."
echo "Safe to run again (idempotent where possible)."
