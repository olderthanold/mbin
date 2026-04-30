#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
SCRIPT_NAME="0web.sh"
SCRIPT_VERSION="v12"

# 0web.sh v12
#
# Purpose:
#   Wrapper to set up Nginx website entry + certificate in one run.
#
# Args:
#   $1 domain (required; must contain a dot, e.g. something.cz)
#   $2 web root path (optional)
#
# Behavior:
#   - Calls web1_webs.sh first
#   - Calls web1_webroot.sh second
#   - Calls web1_adapt_index.sh third
#   - Calls web1_cert_nginx.sh fourth
#   - Calls web1_entry_nginx.sh with domain + optional web root fifth

# Resolve child scripts strictly from the webi subdirectory next to this script.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WEBI_DIR="$SCRIPT_DIR/webi"
WEB_WEBS_SCRIPT="$WEBI_DIR/web1_webs.sh"
WEB_ROOT_SCRIPT="$WEBI_DIR/web1_webroot.sh"
WEB_ADAPT_INDEX_SCRIPT="$WEBI_DIR/web1_adapt_index.sh"
WEB_ENTRY_SCRIPT="$WEBI_DIR/web1_entry_nginx.sh"
WEB_CERT_SCRIPT="$WEBI_DIR/web1_cert_nginx.sh"
WEB_BASE_NAME="webs"
WEB_BASE_DIR="${WEB_BASE_DIR:-/m/${WEB_BASE_NAME}}"
export WEB_BASE_DIR

show_help() {
  echo "Usage: $0 <domain> [web_root]"
  echo ""
  echo "Domain rule: must contain '.' (dot)."
  echo "Examples:"
  echo "  $0 something.cz"
  echo "  $0 something.cz $WEB_BASE_DIR/something.cz"
}

validate_domain_arg() {
  local domain="${1:-}"
  [[ -n "$domain" && "$domain" == *.* ]]
}

get_script_version() {
  local script_path="$1"
  awk '/^# [[:alnum:]_.-]+ v[0-9]+/ {print $3; exit}' "$script_path"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
  show_help
  exit 1
fi

DOMAIN="$1"
WEB_ROOT="${2:-}"

if ! validate_domain_arg "$DOMAIN"; then
  echo -e "${RED}Error: invalid domain '$DOMAIN' (must contain '.').${NC}"
  show_help
  exit 1
fi

if [[ ! -f "$WEB_ENTRY_SCRIPT" ]]; then
  echo -e "${RED}Error: required script not found: $WEB_ENTRY_SCRIPT${NC}"
  exit 1
fi

if [[ ! -f "$WEB_WEBS_SCRIPT" ]]; then
  echo -e "${RED}Error: required script not found: $WEB_WEBS_SCRIPT${NC}"
  exit 1
fi

if [[ ! -f "$WEB_CERT_SCRIPT" ]]; then
  echo -e "${RED}Error: required script not found: $WEB_CERT_SCRIPT${NC}"
  exit 1
fi

if [[ ! -f "$WEB_ROOT_SCRIPT" ]]; then
  echo -e "${RED}Error: required script not found: $WEB_ROOT_SCRIPT${NC}"
  exit 1
fi

if [[ ! -f "$WEB_ADAPT_INDEX_SCRIPT" ]]; then
  echo -e "${RED}Error: required script not found: $WEB_ADAPT_INDEX_SCRIPT${NC}"
  exit 1
fi

WEB_WEBS_VERSION="$(get_script_version "$WEB_WEBS_SCRIPT")"
WEB_ROOT_VERSION="$(get_script_version "$WEB_ROOT_SCRIPT")"
WEB_ADAPT_INDEX_VERSION="$(get_script_version "$WEB_ADAPT_INDEX_SCRIPT")"
WEB_CERT_VERSION="$(get_script_version "$WEB_CERT_SCRIPT")"
WEB_ENTRY_VERSION="$(get_script_version "$WEB_ENTRY_SCRIPT")"

echo -e "${YELLOW}Running ${SCRIPT_NAME} ${SCRIPT_VERSION}${NC}"
echo "Domain arg: $DOMAIN"
echo "Web root arg: ${WEB_ROOT:-<auto:$WEB_BASE_DIR/$DOMAIN>}"
echo "Script base path (script location): $WEBI_DIR"
echo "Resolved child scripts and versions:"
echo "  - $WEB_WEBS_SCRIPT ${WEB_WEBS_VERSION:-<unknown>}"
echo "  - $WEB_ROOT_SCRIPT ${WEB_ROOT_VERSION:-<unknown>}"
echo "  - $WEB_ADAPT_INDEX_SCRIPT ${WEB_ADAPT_INDEX_VERSION:-<unknown>}"
echo "  - $WEB_CERT_SCRIPT ${WEB_CERT_VERSION:-<unknown>}"
echo "  - $WEB_ENTRY_SCRIPT ${WEB_ENTRY_VERSION:-<unknown>}"

echo -e "${YELLOW}[1/5] Running web1_webs.sh ${WEB_WEBS_VERSION:-<unknown>} ...${NC}"
bash "$WEB_WEBS_SCRIPT" "$DOMAIN"

echo -e "${YELLOW}[2/5] Running web1_webroot.sh ${WEB_ROOT_VERSION:-<unknown>} ...${NC}"
bash "$WEB_ROOT_SCRIPT" "$DOMAIN" "${WEB_ROOT:-}"

echo -e "${YELLOW}[3/5] Running web1_adapt_index.sh ${WEB_ADAPT_INDEX_VERSION:-<unknown>} ...${NC}"
bash "$WEB_ADAPT_INDEX_SCRIPT" "$DOMAIN" "${WEB_ROOT:-}"

echo -e "${YELLOW}[4/5] Running web1_cert_nginx.sh ${WEB_CERT_VERSION:-<unknown>} ...${NC}"
bash "$WEB_CERT_SCRIPT" "$DOMAIN"

echo -e "${YELLOW}[5/5] Running web1_entry_nginx.sh ${WEB_ENTRY_VERSION:-<unknown>} ...${NC}"
if [[ -n "$WEB_ROOT" ]]; then
  bash "$WEB_ENTRY_SCRIPT" "$DOMAIN" "$WEB_ROOT"
else
  bash "$WEB_ENTRY_SCRIPT" "$DOMAIN"
fi

echo -e "${GREEN}Done. 0web workflow complete.${NC}"
