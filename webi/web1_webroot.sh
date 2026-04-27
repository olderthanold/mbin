#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# web1_webroot.sh v04
#
# Purpose:
#   Ensure website web root exists and has a default index page when missing.
#
# Args:
#   $1 website/domain (required; must contain a dot, e.g. something.cz)
#   $2 web root path (optional)
#      - absolute path (starts with /): used as-is
#      - relative name/path: resolved under /m web base + <arg>
#      - omitted: defaults to /m web base + <domain>

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  local web_base_name="webs"
  local web_base_dir="${WEB_BASE_DIR:-/m/${web_base_name}}"
  echo "Usage: $0 <domain> [web_root]"
  echo ""
  echo "Domain rule: must contain '.' (dot)."
  echo "Examples:"
  echo "  $0 something.cz"
  echo "  $0 something.cz $web_base_dir/something.cz"
  echo "  $0 something.cz llm129"
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
WEB_BASE_NAME="webs"
WEB_BASE_DIR="${WEB_BASE_DIR:-/m/${WEB_BASE_NAME}}"

if ! validate_domain_arg "$DOMAIN"; then
  echo -e "${RED}Error: invalid domain '$DOMAIN' (must contain '.').${NC}"
  show_help
  exit 1
fi

if [[ -n "${2:-}" ]]; then
  if [[ "$2" == /* ]]; then
    WEB_ROOT="$2"
  else
    WEB_ROOT="$WEB_BASE_DIR/$2"
  fi
else
  WEB_ROOT="$WEB_BASE_DIR/$DOMAIN"
fi

TARGET_INDEX_HTM="$WEB_ROOT/index.htm"
TARGET_INDEX_HTML="$WEB_ROOT/index.html"
CUSTOM_TEMPLATE="$SCRIPT_DIR/index.htm"
NGINX_TEMPLATE="/var/www/html/index.nginx-debian.html"
OWNER_USER="${SUDO_USER:-${USER:-$(whoami)}}"
OWNER_GROUP="www-data"

if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo).${NC}"
  exit 1
fi

if ! id "$OWNER_USER" >/dev/null 2>&1; then
  echo -e "${RED}Error: owner user not found: $OWNER_USER${NC}"
  exit 1
fi

if ! getent group "$OWNER_GROUP" >/dev/null 2>&1; then
  echo -e "${YELLOW}Group '$OWNER_GROUP' not found. Creating system group.${NC}"
  groupadd --system "$OWNER_GROUP"
fi

echo -e "${YELLOW}Running web1_webroot.sh v04${NC}"
echo "Using website/domain: $DOMAIN"
echo "Using web root: $WEB_ROOT"

CREATED_WEB_ROOT="false"
if [[ -d "$WEB_ROOT" ]]; then
  echo "WEB_ROOT already exists, leaving directory as-is: $WEB_ROOT"
else
  echo -e "${YELLOW}[1/3] Creating web root directory...${NC}"
  echo -e "${RED}[TRIAGE][web1_webroot.sh v04] mkdir -p $WEB_ROOT${NC}"
  mkdir -p "$WEB_ROOT"
  chown "$OWNER_USER:$OWNER_GROUP" "$WEB_ROOT"
  chmod 2755 "$WEB_ROOT"
  echo "Created WEB_ROOT: $WEB_ROOT"
  echo "Assigned owner: $OWNER_USER:$OWNER_GROUP"
  echo "Assigned permissions: rwxr-sr-x"
  CREATED_WEB_ROOT="true"
fi

echo -e "${YELLOW}[2/3] Checking index files in web root...${NC}"
if [[ "$CREATED_WEB_ROOT" != "true" ]]; then
  echo "WEB_ROOT existed before this run, leaving content untouched (skip initialize)."
elif [[ -f "$TARGET_INDEX_HTM" || -f "$TARGET_INDEX_HTML" ]]; then
  echo "Index file already exists (skip initialize)."
else
  if [[ -f "$CUSTOM_TEMPLATE" ]]; then
    echo "No index found. Copying custom template: $CUSTOM_TEMPLATE -> $TARGET_INDEX_HTM"
    echo -e "${RED}[TRIAGE][web1_webroot.sh v04] cp $CUSTOM_TEMPLATE $TARGET_INDEX_HTM${NC}"
    cp "$CUSTOM_TEMPLATE" "$TARGET_INDEX_HTM"
    chown "$OWNER_USER:$OWNER_GROUP" "$TARGET_INDEX_HTM"
    chmod 644 "$TARGET_INDEX_HTM"
    echo "Created page from custom template: $TARGET_INDEX_HTM"
  elif [[ -f "$NGINX_TEMPLATE" ]]; then
    echo "Custom template not found. Using nginx default template: $NGINX_TEMPLATE"
    echo -e "${RED}[TRIAGE][web1_webroot.sh v04] cp $NGINX_TEMPLATE $TARGET_INDEX_HTM${NC}"
    cp "$NGINX_TEMPLATE" "$TARGET_INDEX_HTM"
    sed -i "s|<h1>Welcome to nginx!</h1>|<h1>Welcome to ${OWNER_USER} @ ${DOMAIN} nginx!</h1>|" "$TARGET_INDEX_HTM"
    chown "$OWNER_USER:$OWNER_GROUP" "$TARGET_INDEX_HTM"
    chmod 644 "$TARGET_INDEX_HTM"
    echo "Created personalized page: $TARGET_INDEX_HTM"
  else
    echo -e "${YELLOW}No template found (skip index init): $CUSTOM_TEMPLATE and $NGINX_TEMPLATE${NC}"
  fi
fi

echo -e "${YELLOW}[3/3] Finalizing web root ownership...${NC}"
if [[ "$CREATED_WEB_ROOT" == "true" ]]; then
  chown "$OWNER_USER:$OWNER_GROUP" "$WEB_ROOT"
  echo "Applied owner to newly created WEB_ROOT: $OWNER_USER:$OWNER_GROUP"
else
  echo "WEB_ROOT existed before this run, leaving ownership untouched."
fi

echo -e "${GREEN}Done. Web root ready: $WEB_ROOT${NC}"
