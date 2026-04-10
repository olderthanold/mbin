#!/usr/bin/env bash
set -euo pipefail

# web_webs.sh v02
#
# Purpose:
#   Ensure shared /webs directory exists, owned by www-data, and world-writable.

if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

echo "Running web_webs.sh v02"

WEBS_DIR="/webs"

echo "[1/3] Ensuring directory exists: $WEBS_DIR"
mkdir -p "$WEBS_DIR"

echo "[2/3] Setting owner: chown www-data:www-data $WEBS_DIR"
chown www-data:www-data "$WEBS_DIR"

echo "[3/3] Setting permissions: chmod 777 $WEBS_DIR"
chmod 777 "$WEBS_DIR"

echo "Done. Shared webs directory ready: $WEBS_DIR"
