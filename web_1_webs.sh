#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# web_1_webs.sh v02
#
# Purpose:
#   Ensure shared /webs directory exists, owned by www-data, and world-writable.

if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo).${NC}"
  exit 1
fi

echo -e "${YELLOW}Running web_1_webs.sh v02${NC}"

WEBS_DIR="/webs"

echo -e "${YELLOW}[1/3] Ensuring directory exists: $WEBS_DIR${NC}"
mkdir -p "$WEBS_DIR"

echo -e "${YELLOW}[2/3] Setting owner: chown www-data:www-data $WEBS_DIR${NC}"
chown www-data:www-data "$WEBS_DIR"

echo -e "${YELLOW}[3/3] Setting permissions: chmod 777 $WEBS_DIR${NC}"
chmod 777 "$WEBS_DIR"

echo -e "${GREEN}Done. Shared webs directory ready: $WEBS_DIR${NC}"
