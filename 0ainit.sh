#!/usr/bin/env bash
# 0ainit.sh v02
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_NAME="0ainit.sh"
SCRIPT_VERSION="v02"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
AI_DIR="$SCRIPT_DIR/ai"
BUILD_WRAPPER="$SCRIPT_DIR/0buildai.sh"
WEB_WRAPPER="$SCRIPT_DIR/0web.sh"
MODEL_CACHE_SCRIPT="$AI_DIR/bai1_init_model_cache.sh"
NGINX_PROXY_SCRIPT="$AI_DIR/bai1_build_nginx_proxy.sh"
LLAMA_CONTROL_SCRIPT="${LLAMA_CONTROL_SCRIPT:-$SCRIPT_DIR/lctl.sh}"
MODELS_PRESET="${LLAMA_MODELS_PRESET:-$AI_DIR/llama_models.ini}"
BASE_URL="${LLAMA_BASE_URL:-http://127.0.0.1:8080}"
LOAD_TIMEOUT="${LLAMA_LOAD_TIMEOUT:-600}"
INIT_MODEL="${LLAMA_INIT_MODEL:-}"

SNIPPET_PATH="${SNIPPET_PATH:-/etc/nginx/snippets/llama-router-proxy.conf}"
PORT_ALIAS_CONF="${PORT_ALIAS_CONF:-/etc/nginx/conf.d/llama-router-1234.conf}"

show_help() {
  cat <<EOF
Usage: $0 [domain] [web_root]

Initializes the AI router runtime:
  1. Refresh llama-router.service from current model preset.
  2. Ensure all configured GGUF models are downloaded into HF cache.
  3. Without args, list current nginx llama aliases.
     With domain, run 0web.sh and add the domain /llama/ alias.
  4. Ensure at least one model is loaded when a configured model exists.

Environment:
  LLAMA_INIT_MODEL    Optional initial model alias/canonical ID to load.
                      Default: first model section in $MODELS_PRESET.

Examples:
  sudo bash $0
  sudo bash $0 emp2.duckdns.org
  sudo bash $0 emp2.duckdns.org emp2
EOF
}

fail() {
  echo -e "${RED}ERROR: $*${NC}" >&2
  exit 1
}

info() {
  echo -e "${YELLOW}$*${NC}"
}

ok() {
  echo -e "${GREEN}$*${NC}"
}

warn() {
  echo -e "${YELLOW}WARN: $*${NC}"
}

run_root() {
  if [[ "$EUID" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

require_file() {
  local file_path="$1"
  [[ -f "$file_path" ]] || fail "required script not found: $file_path"
}

get_script_version() {
  local script_path="$1"
  awk '/^# [[:alnum:]_.-]+ v[0-9]+/ {print $3; exit}' "$script_path"
}

validate_domain_arg() {
  local domain="${1:-}"
  [[ -n "$domain" && "$domain" == *.* ]]
}

default_web_root_arg() {
  local domain="$1"
  printf '%s\n' "${domain%%.*}"
}

grep_nginx_files() {
  local pattern="$1"
  local path="$2"

  if [[ "$EUID" -eq 0 ]]; then
    grep -Rsl -- "$pattern" "$path" 2>/dev/null || true
  else
    sudo grep -Rsl -- "$pattern" "$path" 2>/dev/null || true
  fi
}

root_test() {
  if [[ "$EUID" -eq 0 ]]; then
    test "$@"
  else
    sudo test "$@"
  fi
}

list_nginx_aliases() {
  info "Nginx llama aliases"

  if ! command -v nginx >/dev/null 2>&1; then
    warn "nginx not found"
    return 0
  fi

  if root_test -f "$PORT_ALIAS_CONF"; then
    echo "port 1234: configured ($PORT_ALIAS_CONF)"
  else
    echo "port 1234: missing ($PORT_ALIAS_CONF)"
  fi

  echo "domain /llama/ aliases:"
  local found="false"
  local site_path
  local domain
  while IFS= read -r site_path; do
    [[ -n "$site_path" ]] || continue
    found="true"
    domain="$(basename "$site_path")"
    if root_test -e "/etc/nginx/sites-enabled/$domain"; then
      printf '  %-32s enabled\n' "$domain"
    else
      printf '  %-32s available-only\n' "$domain"
    fi
  done < <(grep_nginx_files "$SNIPPET_PATH" "/etc/nginx/sites-available")

  if [[ "$found" != "true" ]]; then
    echo "  <none>"
  fi
}

first_model_from_preset() {
  awk '
    /^\[[^]]+\]$/ {
      section = $0
      gsub(/^\[/, "", section)
      gsub(/\]$/, "", section)
      if (section != "*") {
        print section
        exit
      }
    }
  ' "$MODELS_PRESET"
}

loaded_models() {
  LLAMA_BASE_URL="$BASE_URL" bash "$LLAMA_CONTROL_SCRIPT" loaded 2>/dev/null || true
}

ensure_initial_model_loaded() {
  local loaded
  local model

  info "[4/4] Ensuring at least one llama model is loaded..."

  if [[ ! -f "$LLAMA_CONTROL_SCRIPT" ]]; then
    warn "llama control script not found: $LLAMA_CONTROL_SCRIPT"
    warn "The /llama/ UI/API can be reachable, but chat will not work until you load a model manually."
    return 0
  fi

  loaded="$(loaded_models)"
  if [[ -n "$loaded" && "$loaded" != "none" ]]; then
    ok "Model already loaded:"
    printf '%s\n' "$loaded"
    return 0
  fi

  model="$INIT_MODEL"
  if [[ -z "$model" ]]; then
    if [[ -f "$MODELS_PRESET" ]]; then
      model="$(first_model_from_preset)"
    else
      warn "models preset not found: $MODELS_PRESET"
    fi
  fi

  if [[ -z "$model" ]]; then
    warn "No configured model found. The /llama/ UI/API can be reachable, but inference will not work yet."
    warn "Add a model to $MODELS_PRESET or load one manually with: lctl.sh load <model>"
    return 0
  fi

  info "No model is loaded. Loading initial model: $model"
  if LLAMA_BASE_URL="$BASE_URL" LLAMA_LOAD_TIMEOUT="$LOAD_TIMEOUT" bash "$LLAMA_CONTROL_SCRIPT" load "$model"; then
    ok "Initial model loaded: $model"
  else
    warn "Initial model load failed: $model"
    warn "The /llama/ UI/API can be reachable, but chat will not work until you load a model manually: lctl.sh load <model>"
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

if [[ "$#" -gt 2 ]]; then
  show_help
  exit 1
fi

DOMAIN="${1:-}"
WEB_ROOT_ARG="${2:-}"

if [[ -n "$DOMAIN" ]] && ! validate_domain_arg "$DOMAIN"; then
  fail "invalid domain '$DOMAIN' (must contain '.')"
fi

if [[ -n "$DOMAIN" && -z "$WEB_ROOT_ARG" ]]; then
  WEB_ROOT_ARG="$(default_web_root_arg "$DOMAIN")"
fi

require_file "$BUILD_WRAPPER"
require_file "$WEB_WRAPPER"
require_file "$MODEL_CACHE_SCRIPT"
require_file "$NGINX_PROXY_SCRIPT"
require_file "$LLAMA_CONTROL_SCRIPT"

BUILD_VERSION="$(get_script_version "$BUILD_WRAPPER")"
WEB_VERSION="$(get_script_version "$WEB_WRAPPER")"
MODEL_CACHE_VERSION="$(get_script_version "$MODEL_CACHE_SCRIPT")"
NGINX_PROXY_VERSION="$(get_script_version "$NGINX_PROXY_SCRIPT")"
LLAMA_CONTROL_VERSION="$(get_script_version "$LLAMA_CONTROL_SCRIPT")"

info "Running ${SCRIPT_NAME} ${SCRIPT_VERSION}"
echo "Script base path: $SCRIPT_DIR"
echo "Domain arg: ${DOMAIN:-<none>}"
echo "Web root arg: ${WEB_ROOT_ARG:-<none>}"
echo "Resolved child scripts and versions:"
echo "  - $BUILD_WRAPPER ${BUILD_VERSION:-<unknown>}"
echo "  - $MODEL_CACHE_SCRIPT ${MODEL_CACHE_VERSION:-<unknown>}"
echo "  - $WEB_WRAPPER ${WEB_VERSION:-<unknown>}"
echo "  - $NGINX_PROXY_SCRIPT ${NGINX_PROXY_VERSION:-<unknown>}"
echo "  - $LLAMA_CONTROL_SCRIPT ${LLAMA_CONTROL_VERSION:-<unknown>}"
echo "Initial model override: ${INIT_MODEL:-<first preset model>}"

info "[1/4] Refreshing llama router service from current model preset..."
run_root bash "$BUILD_WRAPPER" --service-only

info "[2/4] Ensuring configured GGUF models are downloaded..."
bash "$MODEL_CACHE_SCRIPT"

if [[ -z "$DOMAIN" ]]; then
  info "[3/4] Listing nginx aliases..."
  list_nginx_aliases
  ensure_initial_model_loaded
  ok "Done. AI init check complete."
  exit 0
fi

info "[3/4] Creating/updating web and nginx llama alias..."
run_root bash "$WEB_WRAPPER" "$DOMAIN" "$WEB_ROOT_ARG"
run_root bash "$NGINX_PROXY_SCRIPT" "$DOMAIN"
list_nginx_aliases
ensure_initial_model_loaded

ok "Done. AI init workflow complete."
