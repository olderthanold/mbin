#!/usr/bin/env bash
# bai1_build_settings.sh v01
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SERVICE_NAME="${SERVICE_NAME:-llama-router}"
LLAMA_USER="${LLAMA_USER:-${SUDO_USER:-$(id -un)}}"
LLAMA_GROUP="$(id -gn "${LLAMA_USER}" 2>/dev/null || echo "${LLAMA_USER}")"
HF_CACHE_DIR="${HF_CACHE_DIR:-/m/hfcache}"
HUGGINGFACE_HUB_CACHE="${HUGGINGFACE_HUB_CACHE:-${HF_CACHE_DIR}/hub}"
HF_HUB_CACHE="${HF_HUB_CACHE:-${HUGGINGFACE_HUB_CACHE}}"
TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE:-${HF_CACHE_DIR}/transformers}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HF_CACHE_DIR}/xdg}"
SETTINGS_ENV_FILE="${SETTINGS_ENV_FILE:-/etc/default/${SERVICE_NAME}}"
AI_UFW_PORTS="${AI_UFW_PORTS:-8080/tcp 1234/tcp}"
AI_UFW_ENABLE="${AI_UFW_ENABLE:-false}"

info() {
  echo -e "${YELLOW}$*${NC}"
}

ok() {
  echo -e "${GREEN}OK: $*${NC}"
}

fail() {
  echo -e "${RED}ERROR: $*${NC}" >&2
  exit 1
}

run_root() {
  if [[ "$EUID" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

validate_path() {
  local label="$1"
  local path="$2"

  case "$path" in
    ""|"/"|"."|".."|"/m"|"/m/"|"/home"|"/home/"|"/root"|"/root/"|"/usr"|"/usr/"|"/opt"|"/opt/"|"/var"|"/var/")
      fail "refusing unsafe ${label}: ${path:-<empty>}"
      ;;
  esac
}

ensure_hf_cache() {
  validate_path "HF_CACHE_DIR" "$HF_CACHE_DIR"
  info "[1/4] Ensuring Hugging Face cache directories..."
  run_root mkdir -p "$HF_CACHE_DIR" "$HUGGINGFACE_HUB_CACHE" "$TRANSFORMERS_CACHE" "$XDG_CACHE_HOME"
  run_root chown -R "$LLAMA_USER:$LLAMA_GROUP" "$HF_CACHE_DIR"
  run_root chmod 775 "$HF_CACHE_DIR" "$HUGGINGFACE_HUB_CACHE" "$TRANSFORMERS_CACHE" "$XDG_CACHE_HOME"
  ok "HF cache ready: $HF_CACHE_DIR"
}

write_env_file() {
  validate_path "SETTINGS_ENV_FILE" "$SETTINGS_ENV_FILE"
  info "[2/4] Writing router environment file: $SETTINGS_ENV_FILE"
  run_root mkdir -p "$(dirname "$SETTINGS_ENV_FILE")"
  run_root tee "$SETTINGS_ENV_FILE" >/dev/null <<EOF_SETTINGS
HF_HOME=${HF_CACHE_DIR}
HF_HUB_CACHE=${HF_HUB_CACHE}
HUGGINGFACE_HUB_CACHE=${HUGGINGFACE_HUB_CACHE}
TRANSFORMERS_CACHE=${TRANSFORMERS_CACHE}
XDG_CACHE_HOME=${XDG_CACHE_HOME}
EOF_SETTINGS
  run_root chmod 0644 "$SETTINGS_ENV_FILE"
  ok "Environment file written: $SETTINGS_ENV_FILE"
}

ensure_ufw() {
  info "[3/4] Ensuring UFW exists and AI ports are allowed..."
  if ! command -v ufw >/dev/null 2>&1; then
    info "ufw not found. Installing ufw..."
    run_root apt-get update
    run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y ufw
  fi

  local port
  for port in $AI_UFW_PORTS; do
    run_root ufw allow "$port"
  done

  if [[ "$AI_UFW_ENABLE" == "true" ]]; then
    info "AI_UFW_ENABLE=true, ensuring SSH/HTTP/HTTPS before enabling UFW..."
    run_root ufw allow 22/tcp
    run_root ufw allow 80/tcp
    run_root ufw allow 443/tcp
    run_root ufw --force enable
  else
    info "Leaving UFW enable state unchanged. Set AI_UFW_ENABLE=true to enable it here."
  fi
}

print_summary() {
  info "[4/4] Current AI build settings summary"
  echo "HF_CACHE_DIR=$HF_CACHE_DIR"
  echo "SETTINGS_ENV_FILE=$SETTINGS_ENV_FILE"
  if command -v du >/dev/null 2>&1 && [[ -d "$HF_CACHE_DIR" ]]; then
    du -sh "$HF_CACHE_DIR" || true
  fi
  if command -v ufw >/dev/null 2>&1; then
    run_root ufw status numbered || true
  fi
}

info "Running bai1_build_settings.sh v01"
ensure_hf_cache
write_env_file
ensure_ufw
print_summary
ok "AI build settings complete."
