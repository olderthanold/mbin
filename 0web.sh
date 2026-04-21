#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 0web.sh v07
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
#   - Calls web1_cert_nginx.sh second
#   - Calls web1_entry_nginx.sh with domain + optional web root third

# Resolve child scripts relative to the directory where 0web.sh is executed from.
WEBI_DIR="./webi"
WEB_WEBS_SCRIPT="$WEBI_DIR/web1_webs.sh"
WEB_ENTRY_SCRIPT="$WEBI_DIR/web1_entry_nginx.sh"
WEB_CERT_SCRIPT="$WEBI_DIR/web1_cert_nginx.sh"

show_help() {
  echo "Usage: $0 <domain> [web_root]"
  echo ""
  echo "Domain rule: must contain '.' (dot)."
  echo "Examples:"
  echo "  $0 something.cz"
  echo "  $0 something.cz /webs/something.cz"
}

validate_domain_arg() {
  local domain="${1:-}"
  [[ -n "$domain" && "$domain" == *.* ]]
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

echo -e "${YELLOW}Running 0web.sh v07${NC}"
echo "Domain arg: $DOMAIN"
echo "Web root arg: ${WEB_ROOT:-<auto:/webs/$DOMAIN>}"
echo "Script base path (run dir relative): $WEBI_DIR"

echo -e "${YELLOW}[1/3] Running web1_webs.sh ...${NC}"
bash "$WEB_WEBS_SCRIPT" "$DOMAIN"

echo -e "${YELLOW}[2/3] Running web1_cert_nginx.sh ...${NC}"
bash "$WEB_CERT_SCRIPT" "$DOMAIN"

echo -e "${YELLOW}[3/3] Running web1_entry_nginx.sh ...${NC}"
if [[ -n "$WEB_ROOT" ]]; then
  bash "$WEB_ENTRY_SCRIPT" "$DOMAIN" "$WEB_ROOT"
else
  bash "$WEB_ENTRY_SCRIPT" "$DOMAIN"
fi

echo -e "${GREEN}Done. 0web workflow complete.${NC}"
