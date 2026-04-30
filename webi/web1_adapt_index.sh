#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# web1_adapt_index.sh v01
#
# Purpose:
#   Adapt copied llmweb index.htm for a concrete domain and host IPs.

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

resolve_web_root() {
  local domain="$1"
  local root_arg="${2:-}"
  local web_base_name="webs"
  local web_base_dir="${WEB_BASE_DIR:-/m/${web_base_name}}"

  if [[ -n "$root_arg" ]]; then
    if [[ "$root_arg" == /* ]]; then
      printf '%s\n' "$root_arg"
    else
      printf '%s\n' "$web_base_dir/$root_arg"
    fi
  else
    printf '%s\n' "$web_base_dir/$domain"
  fi
}

get_public_ip() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true
  fi
}

get_private_ip() {
  local ip_addr=""

  if command -v ip >/dev/null 2>&1; then
    ip_addr="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}')"
  fi

  if [[ -z "$ip_addr" ]] && command -v hostname >/dev/null 2>&1; then
    ip_addr="$(hostname -I 2>/dev/null | tr ' ' '\n' | awk '/^[0-9]+\./ {print; exit}')"
  fi

  printf '%s\n' "$ip_addr"
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
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

if ! validate_domain_arg "$DOMAIN"; then
  echo -e "${RED}Error: invalid domain '$DOMAIN' (must contain '.').${NC}"
  show_help
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo).${NC}"
  exit 1
fi

WEB_ROOT="$(resolve_web_root "$DOMAIN" "${2:-}")"
TARGET_INDEX_HTM="$WEB_ROOT/index.htm"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LLMWEB_SOURCE="$REPO_DIR/llmweb"
DOMAIN_PREFIX="${DOMAIN%%.*}"
PUBLIC_IP="$(get_public_ip)"
PRIVATE_IP="$(get_private_ip)"
PUBLIC_IP="${PUBLIC_IP:-unknown}"
PRIVATE_IP="${PRIVATE_IP:-unknown}"
H1_TEXT="${DOMAIN} - ${PUBLIC_IP} - ${PRIVATE_IP}"

echo -e "${YELLOW}Running web1_adapt_index.sh v01${NC}"
echo "Using website/domain: $DOMAIN"
echo "Using web root: $WEB_ROOT"
echo "Resolved title: $DOMAIN_PREFIX"
echo "Resolved H1: $H1_TEXT"

if [[ ! -f "$TARGET_INDEX_HTM" ]]; then
  echo -e "${RED}Error: target index not found: $TARGET_INDEX_HTM${NC}"
  exit 1
fi

if [[ "$(readlink -f "$WEB_ROOT")" == "$(readlink -f "$LLMWEB_SOURCE")" ]]; then
  echo -e "${RED}Error: refusing to adapt source template directory: $LLMWEB_SOURCE${NC}"
  echo -e "${YELLOW}Run 0web with the default web root, or pass a separate target directory.${NC}"
  exit 1
fi

TITLE_ESC="$(escape_sed_replacement "$DOMAIN_PREFIX")"
H1_ESC="$(escape_sed_replacement "$H1_TEXT")"

echo -e "${YELLOW}[1/2] Updating title in target index...${NC}"
sed -i -E "s|<title>[^<]*</title>|<title>${TITLE_ESC}</title>|" "$TARGET_INDEX_HTM"

echo -e "${YELLOW}[2/2] Updating page H1 in target index...${NC}"
if grep -Eq '<h1 id="page-title"[^>]*>' "$TARGET_INDEX_HTM"; then
  sed -i -E "s|<h1 id=\"page-title\"[^>]*>[^<]*</h1>|<h1 id=\"page-title\">${H1_ESC}</h1>|" "$TARGET_INDEX_HTM"
else
  sed -i -E "s|<body>|<body>\n    <h1 id=\"page-title\">${H1_ESC}</h1>|" "$TARGET_INDEX_HTM"
fi

echo -e "${GREEN}Done. Adapted index: $TARGET_INDEX_HTM${NC}"
