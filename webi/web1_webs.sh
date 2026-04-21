#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# web1_webs.sh v07
#
# Purpose:
#   Ensure shared /webs directory exists, owned by www-data, and world-writable.

show_help() {
  echo "Usage: $0 <domain>"
  echo ""
  echo "Domain rule: must contain '.' (dot)."
  echo "Example: $0 something.cz"
}

validate_domain_arg() {
  local domain="${1:-}"
  [[ -n "$domain" && "$domain" == *.* ]]
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

if [[ "$#" -ne 1 ]]; then
  show_help
  exit 1
fi

DOMAIN="$1"

if ! validate_domain_arg "$DOMAIN"; then
  echo -e "${RED}Error: invalid domain '$DOMAIN' (must contain '.').${NC}"
  show_help
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo).${NC}"
  exit 1
fi

echo -e "${YELLOW}Running web1_webs.sh v07${NC}"
echo "Domain arg: $DOMAIN"

WEBS_DIR="/webs"

echo -e "${YELLOW}[1/3] Ensuring directory exists: $WEBS_DIR${NC}"
echo -e "${RED}[TRIAGE][web1_webs.sh v07] mkdir -p $WEBS_DIR${NC}"
mkdir -p "$WEBS_DIR"

echo -e "${YELLOW}[2/3] Setting owner: chown www-data:www-data $WEBS_DIR${NC}"
chown www-data:www-data "$WEBS_DIR"

echo -e "${YELLOW}[3/3] Setting permissions: chmod 777 $WEBS_DIR${NC}"
chmod 777 "$WEBS_DIR"

echo -e "${GREEN}Done. Shared webs directory ready: $WEBS_DIR${NC}"
