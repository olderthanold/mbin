#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures

# Server/instance-level initialization.
# Scope: host-wide configuration (packages, SSH daemon, firewall/network/web service).

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

print_sep() {
  printf '================================================================================\n'
}

print_center_equals() {
  local title="$1"
  local width=80
  local content=" ${title} "

  if (( ${#content} >= width )); then
    printf '%s\n' "$title"
    return
  fi

  local pad_total=$((width - ${#content}))
  local left=$((pad_total / 2))
  local right=$((pad_total - left))

  printf '%*s%s%*s\n' "$left" '' "$content" "$right" '' | tr ' ' '='
}

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
  "$SCRIPT_DIR/root_mbin_path.sh"; do
  require_file "$f"
done

if [[ "$EUID" -ne 0 ]]; then
  echo "Error: run as root (use sudo), e.g.:"
  echo "  sudo bash $0"
  exit 1
fi

print_sep
print_center_equals "Running initinst.sh v01 (instance/server setup)"
print_sep

echo ""
print_center_equals "[1/4] update_inst.sh v01 - update apt packages and install base tools (mc)"
bash "$SCRIPT_DIR/update_inst.sh"

echo ""
print_center_equals "[2/4] ssh_passwd_auth.sh v01 - enable SSH password + keyboard-interactive auth (PAM)"
bash "$SCRIPT_DIR/ssh_passwd_auth.sh"

echo ""
print_center_equals "[3/4] network.sh v01 - configure nginx, firewall rules, and connectivity checks"
bash "$SCRIPT_DIR/network.sh"

echo ""
print_center_equals "[4/4] root_mbin_path.sh v01 - enable root/sudo access to mbin commands"
bash "$SCRIPT_DIR/root_mbin_path.sh"

echo ""
print_sep
echo "initinst complete. Host-level setup finished."
echo "Safe to run again (idempotent where possible)."
print_sep
