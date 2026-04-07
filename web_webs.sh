#!/usr/bin/env bash
set -euo pipefail

# web_webs.sh v01
#
# Purpose:
#   Ensure shared /webs directory exists and is world-writable.

if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

echo "Running web_webs.sh v01"

WEBS_DIR="/webs"

echo "[1/2] Ensuring directory exists: $WEBS_DIR"
mkdir -p "$WEBS_DIR"

echo "[2/2] Setting permissions: chmod 777 $WEBS_DIR"
chmod 777 "$WEBS_DIR"

echo "Done. Shared webs directory ready: $WEBS_DIR"
