#!/usr/bin/env bash
set -euo pipefail

# 0web.sh v04
#
# Purpose:
#   Wrapper to set up Nginx website entry + certificate in one run.
#
# Args:
#   $1 domain (optional)
#   $2 web root path (optional)
#
# Behavior:
#   - Calls web_webs.sh first
#   - Calls web_cert_nginx.sh second
#   - Calls web_entry_nginx.sh with domain + optional web root third
#   - If args are omitted, called scripts use their own defaults

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WEB_WEBS_SCRIPT="$SCRIPT_DIR/web_webs.sh"
WEB_ENTRY_SCRIPT="$SCRIPT_DIR/web_entry_nginx.sh"
WEB_CERT_SCRIPT="$SCRIPT_DIR/web_cert_nginx.sh"

DOMAIN="${1:-}"
WEB_ROOT="${2:-}"

if [[ "$#" -gt 2 ]]; then
  echo "Usage: $0 [domain] [web_root]"
  echo "Examples:"
  echo "  $0"
  echo "  $0 olderthanold.duckdns.org"
  echo "  $0 olderthanold.duckdns.org /webs/olderthanold.duckdns.org"
  exit 1
fi

if [[ ! -f "$WEB_ENTRY_SCRIPT" ]]; then
  echo "Error: required script not found: $WEB_ENTRY_SCRIPT"
  exit 1
fi

if [[ ! -f "$WEB_WEBS_SCRIPT" ]]; then
  echo "Error: required script not found: $WEB_WEBS_SCRIPT"
  exit 1
fi

if [[ ! -f "$WEB_CERT_SCRIPT" ]]; then
  echo "Error: required script not found: $WEB_CERT_SCRIPT"
  exit 1
fi

echo "Running 0web.sh v04"
echo "Domain arg: ${DOMAIN:-<default>}"
echo "Web root arg: ${WEB_ROOT:-<default>}"

echo "[1/3] Running web_webs.sh ..."
bash "$WEB_WEBS_SCRIPT"

echo "[2/3] Running web_cert_nginx.sh ..."
if [[ -n "$DOMAIN" ]]; then
  bash "$WEB_CERT_SCRIPT" "$DOMAIN"
else
  bash "$WEB_CERT_SCRIPT"
fi

echo "[3/3] Running web_entry_nginx.sh ..."
if [[ -n "$DOMAIN" && -n "$WEB_ROOT" ]]; then
  bash "$WEB_ENTRY_SCRIPT" "$DOMAIN" "$WEB_ROOT"
elif [[ -n "$DOMAIN" ]]; then
  bash "$WEB_ENTRY_SCRIPT" "$DOMAIN"
else
  bash "$WEB_ENTRY_SCRIPT"
fi

echo "Done. 0web workflow complete."
