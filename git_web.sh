#!/usr/bin/env bash
set -euo pipefail

echo "Running git_web.sh v01"

# Use command-line arguments if provided, otherwise use defaults
DOMAIN="${1:-oldneues.duckdns.org}"
WEB_DIR="/webs/$DOMAIN"
GIT_LINK="${2:-https://github.com/olderthanold/web.git}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

if ! git -C "$WEB_DIR" pull origin main; then

