#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"  # Script dir
TARGET_USER="${1:-}"  # Optional cloned user; when empty, clone step is skipped

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "Error: required script not found: $f"
    exit 1
  fi
}

for f in \
  "$SCRIPT_DIR/init_1_system.sh" \
  "$SCRIPT_DIR/init_1_user.sh"; do
  require_file "$f"
done

if [[ "$EUID" -ne 0 ]]; then
  echo "Error: run as root (use sudo), e.g.:"
  echo "  sudo bash $0"
  exit 1
fi

echo "Running init_0_main.sh v03 (init_1_system + init_1_user)"

echo "═════════════════════════════════════════════════════════════════════════"
echo "[1/2] init_1_system.sh v11 - server-level setup"
bash "$SCRIPT_DIR/init_1_system.sh"

echo "═════════════════════════════════════════════════════════════════════════"
echo "[2/2] init_1_user.sh v05 - user-level setup"
bash "$SCRIPT_DIR/init_1_user.sh" "$TARGET_USER"

echo ""
echo "init_0_main complete. Server-level and user-level setup finished."
echo "Safe to run again (idempotent where possible)."
