#!/usr/bin/env bash
set -euo pipefail

echo "Running git_mbin.sh v02"

MBIN_DIR="/opt/mbin"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

if ! git -C "$MBIN_DIR" pull origin main; then
  echo "Pull failed, recreating $MBIN_DIR"
  rm -rf "$MBIN_DIR"
  git clone -b main https://github.com/olderthanold/mbin.git "$MBIN_DIR"
fi

chmod +x "$MBIN_DIR"/*.sh 2>/dev/null || true
