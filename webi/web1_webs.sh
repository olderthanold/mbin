#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# web1_webs.sh v05
#
# Purpose:
#   Ensure shared /webs directory exists, owned by www-data, and world-writable.
#   Ensure website directory /webs/<domain> has a default index page if missing.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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

echo -e "${YELLOW}Running web1_webs.sh v05${NC}"
echo "Domain arg: $DOMAIN"

WEBS_DIR="/webs"
WEBSITE_DIR="$WEBS_DIR/$DOMAIN"
TEMPLATE_INDEX="$SCRIPT_DIR/index.htm"
TARGET_INDEX_HTM="$WEBSITE_DIR/index.htm"
TARGET_INDEX_HTML="$WEBSITE_DIR/index.html"

echo -e "${YELLOW}[1/6] Ensuring directory exists: $WEBS_DIR${NC}"
mkdir -p "$WEBS_DIR"

echo -e "${YELLOW}[2/6] Setting owner: chown www-data:www-data $WEBS_DIR${NC}"
chown www-data:www-data "$WEBS_DIR"

echo -e "${YELLOW}[3/6] Setting permissions: chmod 777 $WEBS_DIR${NC}"
chmod 777 "$WEBS_DIR"

echo -e "${YELLOW}[4/6] Ensuring website directory exists: $WEBSITE_DIR${NC}"
mkdir -p "$WEBSITE_DIR"

echo -e "${YELLOW}[5/6] Checking website index files (index.htm / index.html)...${NC}"
if [[ ! -f "$TARGET_INDEX_HTM" && ! -f "$TARGET_INDEX_HTML" ]]; then
  if [[ -f "$TEMPLATE_INDEX" ]]; then
    echo -e "${YELLOW}No index found. Copying template: $TEMPLATE_INDEX -> $TARGET_INDEX_HTM${NC}"
    cp "$TEMPLATE_INDEX" "$TARGET_INDEX_HTM"
    chown www-data:www-data "$TARGET_INDEX_HTM"
    chmod 644 "$TARGET_INDEX_HTM"
  else
    echo -e "${YELLOW}Template not found (skip copy): $TEMPLATE_INDEX${NC}"
  fi
else
  echo -e "${YELLOW}Index file already exists (skip copy).${NC}"
fi

echo -e "${YELLOW}[6/6] Ensuring website directory owner is www-data:www-data${NC}"
chown www-data:www-data "$WEBSITE_DIR"

echo -e "${GREEN}Done. Shared webs directory ready: $WEBS_DIR${NC}"
echo -e "${GREEN}Done. Website directory ready: $WEBSITE_DIR${NC}"
