#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
SCRIPT_NAME="0web.sh"
SCRIPT_VERSION="v15"

# 0web.sh v15
#
# Purpose:
#   Wrapper to set up Nginx website entry + certificate in one run.
#
# Args:
#   $1 domain (required; must contain a dot, e.g. something.cz)
#   $2 web root path (optional; defaults to domain prefix before first dot)
#
# Behavior:
#   - Calls web1_webs.sh first
#   - Calls web1_webroot.sh second
#   - Calls web1_adapt_index.sh third
#   - Calls web1_entry_nginx.sh fourth to create/update HTTP bootstrap config
#   - Calls web1_cert_nginx.sh fifth
#   - Calls web1_entry_nginx.sh with domain + optional web root sixth for final config

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
  echo "Without arguments, prints Nginx/web/UFW status and this help, then exits."
  echo "Run this wrapper without sudo/root. It asks for sudo only for system-level child steps."
  echo ""
  echo "Domain rule: must contain '.' (dot)."
  echo "When web_root is omitted, it defaults to the domain prefix before the first dot."
  echo "Examples:"
  echo "  $0 something.cz"
  echo "  $0 something.cz something"
  echo "  $0 something.cz $WEB_BASE_DIR/something"
}

fail() {
  echo -e "${RED}ERROR: $*${NC}" >&2
  exit 1
}

info() {
  echo -e "${YELLOW}$*${NC}"
}

warn() {
  echo -e "${YELLOW}WARN: $*${NC}"
}

refuse_root_invocation() {
  if [[ "$EUID" -eq 0 ]]; then
    echo -e "${RED}ERROR: Do not run ${SCRIPT_NAME} with sudo/root.${NC}" >&2
    echo -e "${YELLOW}Run it as your normal user; sudo is requested only for system-level child steps.${NC}" >&2
    echo >&2
    show_help
    exit 1
  fi
}

run_root() {
  if [[ "$EUID" -eq 0 ]]; then
    "$@"
  else
    sudo env WEB_BASE_DIR="$WEB_BASE_DIR" M_BASE_DIR="${M_BASE_DIR:-}" "$@"
  fi
}

require_file() {
  local script_path="$1"
  [[ -f "$script_path" ]] || fail "required script not found: $script_path"
}

root_test() {
  if [[ "$EUID" -eq 0 ]]; then
    test "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo test "$@"
  else
    return 1
  fi
}

root_find_sites_available() {
  if root_test -d /etc/nginx/sites-available; then
    if [[ "$EUID" -eq 0 ]]; then
      find /etc/nginx/sites-available -maxdepth 1 -type f -print 2>/dev/null | sort
    elif command -v sudo >/dev/null 2>&1; then
      sudo find /etc/nginx/sites-available -maxdepth 1 -type f -print 2>/dev/null | sort
    fi
  fi
}

nginx_config_root() {
  local site_path="$1"
  if [[ "$EUID" -eq 0 ]]; then
    awk '/^[[:space:]]*root[[:space:]]+/ {gsub(/;/, "", $2); print $2; exit}' "$site_path" 2>/dev/null || true
  elif command -v sudo >/dev/null 2>&1; then
    sudo awk '/^[[:space:]]*root[[:space:]]+/ {gsub(/;/, "", $2); print $2; exit}' "$site_path" 2>/dev/null || true
  else
    awk '/^[[:space:]]*root[[:space:]]+/ {gsub(/;/, "", $2); print $2; exit}' "$site_path" 2>/dev/null || true
  fi
}

print_nginx_status() {
  info "Nginx status"
  if command -v nginx >/dev/null 2>&1; then
    nginx -v 2>&1 || true
  else
    warn "nginx not found"
  fi

  if command -v systemctl >/dev/null 2>&1; then
    echo "nginx active:  $(systemctl is-active nginx 2>/dev/null || true)"
    echo "nginx enabled: $(systemctl is-enabled nginx 2>/dev/null || true)"
  else
    warn "systemctl not found"
  fi
  echo
}

print_configured_webs() {
  info "Configured Nginx websites"

  if ! root_test -d /etc/nginx/sites-available; then
    warn "/etc/nginx/sites-available not found"
    echo
    return 0
  fi

  local found="false"
  local site_path
  local domain
  local enabled_state
  local root_path

  while IFS= read -r site_path; do
    [[ -n "$site_path" ]] || continue
    found="true"
    domain="$(basename "$site_path")"
    if root_test -e "/etc/nginx/sites-enabled/$domain"; then
      enabled_state="enabled"
    else
      enabled_state="available-only"
    fi
    root_path="$(nginx_config_root "$site_path")"
    printf '  %-32s %-15s root=%s\n' "$domain" "$enabled_state" "${root_path:-<none>}"
  done < <(root_find_sites_available)

  if [[ "$found" != "true" ]]; then
    echo "  <none>"
  fi
  echo
}

print_short_ufw_status() {
  info "UFW / open web ports"
  if command -v ufw >/dev/null 2>&1; then
    if [[ "$EUID" -eq 0 ]]; then
      ufw status numbered 2>/dev/null | grep -E 'Status:|22/tcp|80/tcp|443/tcp|8080/tcp|1234/tcp' || true
    else
      sudo ufw status numbered 2>/dev/null | grep -E 'Status:|22/tcp|80/tcp|443/tcp|8080/tcp|1234/tcp' || true
    fi
  else
    warn "ufw not found"
  fi
  echo
}

print_status() {
  info "${SCRIPT_NAME} ${SCRIPT_VERSION} status"
  echo "WEB_BASE_DIR: $WEB_BASE_DIR"
  echo
  print_nginx_status
  print_configured_webs
  print_short_ufw_status
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

refuse_root_invocation

if [[ "$#" -eq 0 ]]; then
  print_status
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
  echo -e "${RED}ERROR: invalid domain '$DOMAIN' (must contain '.').${NC}" >&2
  show_help
  exit 1
fi

if [[ -z "$WEB_ROOT" ]]; then
  WEB_ROOT="${DOMAIN%%.*}"
fi

require_file "$WEB_ENTRY_SCRIPT"
require_file "$WEB_WEBS_SCRIPT"
require_file "$WEB_CERT_SCRIPT"
require_file "$WEB_ROOT_SCRIPT"
require_file "$WEB_ADAPT_INDEX_SCRIPT"

WEB_WEBS_VERSION="$(get_script_version "$WEB_WEBS_SCRIPT")"
WEB_ROOT_VERSION="$(get_script_version "$WEB_ROOT_SCRIPT")"
WEB_ADAPT_INDEX_VERSION="$(get_script_version "$WEB_ADAPT_INDEX_SCRIPT")"
WEB_CERT_VERSION="$(get_script_version "$WEB_CERT_SCRIPT")"
WEB_ENTRY_VERSION="$(get_script_version "$WEB_ENTRY_SCRIPT")"

echo -e "${YELLOW}Running ${SCRIPT_NAME} ${SCRIPT_VERSION}${NC}"
echo "Domain arg: $DOMAIN"
echo "Web root arg: $WEB_ROOT"
echo "Resolved web root path: $([[ "$WEB_ROOT" == /* ]] && printf '%s' "$WEB_ROOT" || printf '%s/%s' "$WEB_BASE_DIR" "$WEB_ROOT")"
echo "Script base path (script location): $WEBI_DIR"
echo "Resolved child scripts and versions:"
echo "  - $WEB_WEBS_SCRIPT ${WEB_WEBS_VERSION:-<unknown>}"
echo "  - $WEB_ROOT_SCRIPT ${WEB_ROOT_VERSION:-<unknown>}"
echo "  - $WEB_ADAPT_INDEX_SCRIPT ${WEB_ADAPT_INDEX_VERSION:-<unknown>}"
echo "  - $WEB_CERT_SCRIPT ${WEB_CERT_VERSION:-<unknown>}"
echo "  - $WEB_ENTRY_SCRIPT ${WEB_ENTRY_VERSION:-<unknown>}"

echo -e "${YELLOW}[1/6] Running web1_webs.sh ${WEB_WEBS_VERSION:-<unknown>} ...${NC}"
run_root bash "$WEB_WEBS_SCRIPT" "$DOMAIN"

echo -e "${YELLOW}[2/6] Running web1_webroot.sh ${WEB_ROOT_VERSION:-<unknown>} ...${NC}"
run_root bash "$WEB_ROOT_SCRIPT" "$DOMAIN" "${WEB_ROOT:-}"

echo -e "${YELLOW}[3/6] Running web1_adapt_index.sh ${WEB_ADAPT_INDEX_VERSION:-<unknown>} ...${NC}"
run_root bash "$WEB_ADAPT_INDEX_SCRIPT" "$DOMAIN" "${WEB_ROOT:-}"

echo -e "${YELLOW}[4/6] Running web1_entry_nginx.sh ${WEB_ENTRY_VERSION:-<unknown>} for HTTP bootstrap ...${NC}"
run_root bash "$WEB_ENTRY_SCRIPT" "$DOMAIN" "$WEB_ROOT"

echo -e "${YELLOW}[5/6] Running web1_cert_nginx.sh ${WEB_CERT_VERSION:-<unknown>} ...${NC}"
run_root bash "$WEB_CERT_SCRIPT" "$DOMAIN"

echo -e "${YELLOW}[6/6] Running web1_entry_nginx.sh ${WEB_ENTRY_VERSION:-<unknown>} for final config ...${NC}"
run_root bash "$WEB_ENTRY_SCRIPT" "$DOMAIN" "$WEB_ROOT"

echo -e "${GREEN}Done. 0web workflow complete.${NC}"
