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
  "$SCRIPT_DIR/initinst.sh" \
  "$SCRIPT_DIR/initusr.sh"; do
  require_file "$f"
done

if [[ "$EUID" -ne 0 ]]; then
  echo "Error: run as root (use sudo), e.g.:"
  echo "  sudo bash $0"
  exit 1
fi

echo "=========================================="
echo "Running 0init.sh v01 (initinst + initusr)"
echo "=========================================="

echo "═════════════════════════════════════════════════════════════════════════"
echo "[1/2] initinst.sh v02 - server-level setup"
bash "$SCRIPT_DIR/initinst.sh"

echo "═════════════════════════════════════════════════════════════════════════"
echo "[2/2] initusr.sh v02 - user-level setup"
bash "$SCRIPT_DIR/initusr.sh" "$TARGET_USER"

echo ""
echo "=========================================="
echo "0init complete. Server-level and user-level setup finished."
echo "Safe to run again (idempotent where possible)."
echo "=========================================="
