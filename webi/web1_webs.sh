#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# web1_webs.sh v10
#
# Purpose:
#   Ensure shared web directory exists under /m and is readable by www-data.

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

echo -e "${YELLOW}Running web1_webs.sh v10${NC}"
echo "Domain arg: $DOMAIN"

WEB_GROUP="www-data"
DEPLOY_USER="${SUDO_USER:-${USER:-$(whoami)}}"
M_BASE_DIR="${M_BASE_DIR:-/m}"
WEB_BASE_NAME="webs"
WEBS_DIR="${WEB_BASE_DIR:-${M_BASE_DIR}/${WEB_BASE_NAME}}"

if ! getent group "$WEB_GROUP" >/dev/null 2>&1; then
  echo -e "${YELLOW}Group '$WEB_GROUP' not found. Creating system group.${NC}"
  groupadd --system "$WEB_GROUP"
fi

if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
  echo -e "${RED}Error: deploy user not found: $DEPLOY_USER${NC}"
  exit 1
fi

if [[ "$DEPLOY_USER" != "root" ]]; then
  if id -nG "$DEPLOY_USER" | tr ' ' '\n' | grep -Fxq "$WEB_GROUP"; then
    echo "Deploy user '$DEPLOY_USER' is already in group '$WEB_GROUP'."
  else
    usermod -aG "$WEB_GROUP" "$DEPLOY_USER"
    echo "Added deploy user '$DEPLOY_USER' to group '$WEB_GROUP'."
    echo "Note: a new login session may be required before group membership is visible to that user."
  fi
else
  echo "Deploy user resolved to root; skipping group membership update."
fi

echo -e "${YELLOW}[1/4] Ensuring /m base exists and is traversable${NC}"
mkdir -p "$M_BASE_DIR"
chmod 755 "$M_BASE_DIR"

echo -e "${YELLOW}[2/4] Ensuring directory exists: $WEBS_DIR${NC}"
echo "Info: mkdir -p $WEBS_DIR"
mkdir -p "$WEBS_DIR"

if [[ "$DEPLOY_USER" == "root" ]]; then
  WEBS_OWNER="root"
else
  WEBS_OWNER="$DEPLOY_USER"
fi

echo -e "${YELLOW}[3/4] Setting owner/group: chown $WEBS_OWNER:$WEB_GROUP $WEBS_DIR${NC}"
chown "$WEBS_OWNER:$WEB_GROUP" "$WEBS_DIR"

echo -e "${YELLOW}[4/4] Setting permissions: chmod 2775 $WEBS_DIR${NC}"
chmod 2775 "$WEBS_DIR"

echo -e "${GREEN}Done. Shared webs directory ready: $WEBS_DIR${NC}"
