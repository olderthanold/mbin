#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"  # Script dir

UPDATE_SCRIPT="$SCRIPT_DIR/update_inst.sh"
SSH_SCRIPT="$SCRIPT_DIR/ssh_passwd_auth.sh"
MBIN_SCRIPT="$SCRIPT_DIR/mbin_path.sh"
CLONE_SCRIPT="$SCRIPT_DIR/clone_user.sh"
NETWORK_SCRIPT="$SCRIPT_DIR/network.sh"

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "Error: required script not found: $f"
    exit 1
  fi
}

for f in "$UPDATE_SCRIPT" "$SSH_SCRIPT" "$MBIN_SCRIPT" "$CLONE_SCRIPT" "$NETWORK_SCRIPT"; do
  require_file "$f"
done

if [[ "$EUID" -ne 0 ]]; then
  echo "Error: run as root (use sudo), e.g.:"
  echo "  sudo bash $0"
  exit 1
fi

CURRENT_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"  # Caller user
if [[ -z "$CURRENT_USER" || "$CURRENT_USER" == "root" ]]; then
  CURRENT_USER="ubuntu"  # Fallback user
fi

echo "=========================================="
echo "Running 0init sequence"
echo "Current user for user-level steps: $CURRENT_USER"
echo "=========================================="

echo ""
echo "[1/5] update_inst.sh"
bash "$UPDATE_SCRIPT"

echo ""
echo "[2/5] ssh_passwd_auth.sh"
bash "$SSH_SCRIPT"

echo ""
echo "[3/5] mbin_path.sh (for user: $CURRENT_USER)"
if id "$CURRENT_USER" >/dev/null 2>&1; then
  sudo -u "$CURRENT_USER" -H bash "$MBIN_SCRIPT"
else
  echo "Warning: user '$CURRENT_USER' not found; skipping mbin_path.sh"
fi

echo ""
echo "[4/5] clone_user.sh -> ubun2 from $CURRENT_USER"
if id ubun2 >/dev/null 2>&1; then
  echo "User 'ubun2' already exists; skipping clone step (idempotent behavior)."
else
  bash "$CLONE_SCRIPT" ubun2 "$CURRENT_USER"
fi

echo ""
echo "[5/5] network.sh"
bash "$NETWORK_SCRIPT"

echo ""
echo "=========================================="
echo "0init complete. Safe to run again."
echo "=========================================="
