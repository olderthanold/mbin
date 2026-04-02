#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures.

# Ensure root PATH includes /home/ubuntu/mbin, without duplicate config lines.

if [[ "$EUID" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

echo "Running root_mbin_path.sh v01"

ROOT_BASHRC="/root/.bashrc"
ROOT_PATH_MARKER="# Added by root_mbin_path.sh (ensure /home/ubuntu/mbin in root PATH)"
ROOT_PATH_LINE='export PATH="$PATH:/home/ubuntu/mbin"'

# 1) Root interactive shells: ensure /home/ubuntu/mbin is in /root/.bashrc.
if [[ ! -f "$ROOT_BASHRC" ]]; then
  touch "$ROOT_BASHRC"
fi

if ! grep -Fq "$ROOT_PATH_MARKER" "$ROOT_BASHRC"; then
  {
    echo ""
    echo "$ROOT_PATH_MARKER"
    echo "$ROOT_PATH_LINE"
  } >> "$ROOT_BASHRC"
  echo "Appended root PATH update to: $ROOT_BASHRC"
else
  echo "Root PATH marker already present in: $ROOT_BASHRC"
fi

echo "Done. Root PATH support configured (idempotent)."
