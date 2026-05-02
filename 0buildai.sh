#!/usr/bin/env bash
# 0buildai.sh v03
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_NAME="0buildai.sh"
SCRIPT_VERSION="v03"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
AI_DIR="$SCRIPT_DIR/ai"
SETTINGS_SCRIPT="$AI_DIR/bai1_build_settings.sh"
BUILD_SCRIPT="$AI_DIR/bai1_build_llama.sh"
ROUTER_SERVICE_SCRIPT="$AI_DIR/bai1_build_router_service.sh"

LLAMA_DIR="${LLAMA_DIR:-/m/llama.cpp}"
OWNER_USER="${SUDO_USER:-${USER:-$(id -un)}}"
SERVICE_NAME="${SERVICE_NAME:-llama-router}"
HF_CACHE_DIR="${HF_CACHE_DIR:-/m/hfcache}"
SETTINGS_ENV_FILE="${SETTINGS_ENV_FILE:-/etc/default/${SERVICE_NAME}}"

RESET_BAD_TARGET_DEPRECATED="false"
BUILD_ONLY="false"
SERVICE_ONLY="false"
FORCE="false"
STATUS_ONLY="false"

show_help() {
  cat <<EOF
Usage: $0 [--status|--force|--build-only|--service-only]

Build/update llama.cpp and configure the llama router systemd service.

Defaults:
  LLAMA_DIR=$LLAMA_DIR
  HF_CACHE_DIR=$HF_CACHE_DIR
  SETTINGS_ENV_FILE=$SETTINGS_ENV_FILE
  SETTINGS_SCRIPT=$SETTINGS_SCRIPT
  BUILD_SCRIPT=$BUILD_SCRIPT
  ROUTER_SERVICE_SCRIPT=$ROUTER_SERVICE_SCRIPT

Options:
  --status            Print router/build status and exit.
  --force             Stop/remove llama-router.service, delete LLAMA_DIR,
                      rebuild from scratch, then recreate/restart service.
  --build-only        Run only llama.cpp build verification/setup.
  --service-only      Verify runtime, run settings, and recreate/restart llama-router.service.
  -h, --help          Show this help.
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

validate_destructive_llama_dir() {
  case "$LLAMA_DIR" in
    ""|"/"|"."|".."|"/m"|"/m/"|"/home"|"/home/"|"/root"|"/root/"|"/usr"|"/usr/"|"/opt"|"/opt/"|"/var"|"/var/")
      fail "refusing destructive operation for unsafe LLAMA_DIR: ${LLAMA_DIR:-<empty>}"
      ;;
  esac
}

router_is_active() {
  command -v systemctl >/dev/null 2>&1 || return 1
  systemctl is-active --quiet "${SERVICE_NAME}.service"
}

service_has_expected_settings_config() {
  local unit_file="/etc/systemd/system/${SERVICE_NAME}.service"
  [[ -f "$unit_file" && -f "$SETTINGS_ENV_FILE" ]] || return 1
  grep -Fq "EnvironmentFile=-${SETTINGS_ENV_FILE}" "$unit_file" &&
    grep -Fq "HF_HOME=${HF_CACHE_DIR}" "$SETTINGS_ENV_FILE" &&
    grep -Fq "HF_HUB_CACHE=${HF_CACHE_DIR}/hub" "$SETTINGS_ENV_FILE" &&
    grep -Fq "HUGGINGFACE_HUB_CACHE=${HF_CACHE_DIR}/hub" "$SETTINGS_ENV_FILE" &&
    grep -Fq "TRANSFORMERS_CACHE=${HF_CACHE_DIR}/transformers" "$SETTINGS_ENV_FILE" &&
    grep -Fq "XDG_CACHE_HOME=${HF_CACHE_DIR}/xdg" "$SETTINGS_ENV_FILE"
}

print_file_status() {
  local path="$1"
  if [[ -e "$path" ]]; then
    ls -ld "$path" || true
  else
    echo "$path: <missing>"
  fi
}

runpath_entries_for_binary() {
  local binary_path="$1"

  command -v readelf >/dev/null 2>&1 || return 0
  [[ -e "$binary_path" ]] || return 0

  readelf -d "$binary_path" 2>/dev/null |
    awk -F'[][]' '/RPATH|RUNPATH/ {print $2}' |
    tr ':' '\n' |
    sed '/^$/d'
}

print_legacy_runpath_symlink_status() {
  local binary_path="$1"
  local entry
  local legacy_llama_dir
  local current_target

  while IFS= read -r entry; do
    case "$entry" in
      /*/ai/llama.cpp/build/bin)
        legacy_llama_dir="${entry%/build/bin}"
        if [[ -L "$legacy_llama_dir" ]]; then
          current_target="$(readlink "$legacy_llama_dir")"
          echo "legacy RUNPATH symlink: $legacy_llama_dir -> $current_target"
        elif [[ -e "$legacy_llama_dir" ]]; then
          echo "legacy RUNPATH path exists but is not a symlink: $legacy_llama_dir"
        else
          echo "legacy RUNPATH symlink missing: $legacy_llama_dir -> $LLAMA_DIR"
        fi
        return 0
        ;;
    esac
  done < <(runpath_entries_for_binary "$binary_path")

  echo "legacy RUNPATH symlink: <not applicable>"
}

print_binary_linker_status() {
  local binary_path="$1"
  local entries
  local missing_libs

  echo "--- linker diagnostics: $binary_path"
  if [[ ! -e "$binary_path" ]]; then
    echo "<missing>"
    return 0
  fi

  if command -v readelf >/dev/null 2>&1; then
    entries="$(runpath_entries_for_binary "$binary_path" || true)"
    if [[ -n "$entries" ]]; then
      echo "RUNPATH/RPATH:"
      printf '%s\n' "$entries" | sed 's/^/  - /'
    else
      echo "RUNPATH/RPATH: <none>"
    fi
  else
    echo "RUNPATH/RPATH: <readelf not available>"
  fi

  if command -v ldd >/dev/null 2>&1; then
    missing_libs="$(ldd "$binary_path" 2>&1 | grep 'not found' || true)"
    if [[ -n "$missing_libs" ]]; then
      echo "ldd missing libraries:"
      printf '%s\n' "$missing_libs" | sed 's/^/  /'
    else
      echo "ldd missing libraries: <none>"
    fi
  else
    echo "ldd missing libraries: <ldd not available>"
  fi

  print_legacy_runpath_symlink_status "$binary_path"
}

probe_url() {
  local label="$1"
  local url="$2"

  echo "--- ${label}: ${url}"
  if command -v curl >/dev/null 2>&1; then
    curl -sS --max-time 5 "$url" || true
    echo
  else
    echo "curl not found"
  fi
}

print_ufw_status() {
  info "UFW"
  if command -v ufw >/dev/null 2>&1; then
    run_root ufw status numbered || true
  else
    warn "ufw not found"
  fi
  echo
}

print_router_status() {
  local bind_port="${BIND_PORT:-8080}"

  info "Router/build status"
  echo "Service: ${SERVICE_NAME}.service"
  echo "LLAMA_DIR: $LLAMA_DIR"
  echo "HF_CACHE_DIR: $HF_CACHE_DIR"
  echo "Settings env file: $SETTINGS_ENV_FILE"
  echo "Expected local API: http://127.0.0.1:${bind_port}"
  echo

  info "Systemd"
  if command -v systemctl >/dev/null 2>&1; then
    echo "is-active:  $(systemctl is-active "${SERVICE_NAME}.service" 2>/dev/null || true)"
    echo "is-enabled: $(systemctl is-enabled "${SERVICE_NAME}.service" 2>/dev/null || true)"
    systemctl status "${SERVICE_NAME}.service" --no-pager -l || true
  else
    warn "systemctl not found"
  fi
  echo

  info "Listening ports"
  if command -v ss >/dev/null 2>&1; then
    if [[ "$EUID" -eq 0 ]]; then
      ss -ltnp | grep -E "(:${bind_port}|:1234)[[:space:]]" || true
    else
      ss -ltn | grep -E "(:${bind_port}|:1234)[[:space:]]" || true
    fi
  else
    warn "ss not found"
  fi
  echo

  print_ufw_status

  info "Hugging Face cache"
  if service_has_expected_settings_config; then
    echo "settings config: ok"
  else
    echo "settings config: missing/stale"
  fi
  print_file_status "$SETTINGS_ENV_FILE"
  print_file_status "$HF_CACHE_DIR"
  print_file_status "$HF_CACHE_DIR/hub"
  print_file_status "$HF_CACHE_DIR/transformers"
  print_file_status "$HF_CACHE_DIR/xdg"
  if [[ -d "$HF_CACHE_DIR" ]] && command -v du >/dev/null 2>&1; then
    du -sh "$HF_CACHE_DIR" 2>/dev/null || true
  fi
  echo

  info "llama.cpp files"
  print_file_status "$LLAMA_DIR"
  print_file_status "$LLAMA_DIR/build/bin/llama-server"
  print_file_status "$LLAMA_DIR/build/bin/llama-cli"
  print_binary_linker_status "$LLAMA_DIR/build/bin/llama-server"
  print_binary_linker_status "$LLAMA_DIR/build/bin/llama-cli"
  echo

  info "Local API probes"
  probe_url "health" "http://127.0.0.1:${bind_port}/health"
  probe_url "router models" "http://127.0.0.1:${bind_port}/models"
  probe_url "OpenAI models" "http://127.0.0.1:${bind_port}/v1/models"
  echo

  info "Useful next commands"
  echo "  sudo bash $SCRIPT_DIR/0buildai.sh --status        # show this status"
  echo "  sudo bash $SCRIPT_DIR/0buildai.sh --build-only    # verify/setup build only"
  echo "  sudo bash $SCRIPT_DIR/0buildai.sh --service-only  # verify runtime + recreate/restart router service"
  echo "  sudo bash $SCRIPT_DIR/0buildai.sh --force         # full reset: service + /m/llama.cpp"
  echo "  du -sh $HF_CACHE_DIR"
  echo "  sudo journalctl -u ${SERVICE_NAME}.service -n 100 --no-pager"
}

cleanup_non_git_llama_dir() {
  if [[ ! -d "$LLAMA_DIR" ]]; then
    return 0
  fi

  if [[ -d "$LLAMA_DIR/.git" ]]; then
    return 0
  fi

  validate_destructive_llama_dir
  info "LLAMA_DIR exists but is not a git repository. Removing disposable build target: $LLAMA_DIR"
  run_root rm -rf "$LLAMA_DIR"
  ok "Removed non-git LLAMA_DIR: $LLAMA_DIR"
}

force_reset_if_requested() {
  [[ "$FORCE" == "true" ]] || return 0

  validate_destructive_llama_dir
  info "Force mode enabled: removing ${SERVICE_NAME}.service and LLAMA_DIR."

  if command -v systemctl >/dev/null 2>&1; then
    info "Stopping ${SERVICE_NAME}.service if present..."
    run_root systemctl stop "${SERVICE_NAME}.service" 2>/dev/null || true

    info "Disabling ${SERVICE_NAME}.service if present..."
    run_root systemctl disable "${SERVICE_NAME}.service" 2>/dev/null || true
  else
    info "systemctl not found; skipping service stop/disable."
  fi

  info "Removing systemd unit file if present..."
  run_root rm -f "/etc/systemd/system/${SERVICE_NAME}.service"

  if command -v systemctl >/dev/null 2>&1; then
    info "Reloading systemd manager configuration..."
    run_root systemctl daemon-reload
    run_root systemctl reset-failed "${SERVICE_NAME}.service" 2>/dev/null || true
  fi

  if [[ -e "$LLAMA_DIR" ]]; then
    info "Removing LLAMA_DIR: $LLAMA_DIR"
    run_root rm -rf "$LLAMA_DIR"
  else
    info "LLAMA_DIR already absent: $LLAMA_DIR"
  fi

  ok "Force reset complete. HF cache, nginx proxy config, and webroot were not changed."
}

run_settings_script() {
  local settings_env=(
    "SERVICE_NAME=$SERVICE_NAME"
    "LLAMA_USER=$OWNER_USER"
    "HF_CACHE_DIR=$HF_CACHE_DIR"
    "SETTINGS_ENV_FILE=$SETTINGS_ENV_FILE"
  )

  if [[ "$EUID" -eq 0 ]]; then
    env "${settings_env[@]}" bash "$SETTINGS_SCRIPT"
  else
    sudo env "${settings_env[@]}" bash "$SETTINGS_SCRIPT"
  fi
}

run_router_service_script() {
  local service_env=(
    "SERVICE_NAME=$SERVICE_NAME"
    "LLAMA_WORKDIR=$LLAMA_DIR"
    "LLAMA_BIN=$LLAMA_DIR/build/bin/llama-server"
    "LLAMA_USER=$OWNER_USER"
    "SETTINGS_ENV_FILE=$SETTINGS_ENV_FILE"
  )

  if [[ "$EUID" -eq 0 ]]; then
    env "${service_env[@]}" bash "$ROUTER_SERVICE_SCRIPT"
  else
    sudo env "${service_env[@]}" bash "$ROUTER_SERVICE_SCRIPT"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --status)
      STATUS_ONLY="true"
      shift
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    --reset-bad-target)
      RESET_BAD_TARGET_DEPRECATED="true"
      shift
      ;;
    --build-only)
      BUILD_ONLY="true"
      shift
      ;;
    --service-only)
      SERVICE_ONLY="true"
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

if [[ "$BUILD_ONLY" == "true" && "$SERVICE_ONLY" == "true" ]]; then
  fail "--build-only and --service-only cannot be used together"
fi

if [[ "$FORCE" == "true" && ( "$BUILD_ONLY" == "true" || "$SERVICE_ONLY" == "true" ) ]]; then
  fail "--force cannot be combined with --build-only or --service-only"
fi

if [[ "$STATUS_ONLY" == "true" && ( "$FORCE" == "true" || "$BUILD_ONLY" == "true" || "$SERVICE_ONLY" == "true" ) ]]; then
  fail "--status cannot be combined with action flags"
fi

require_file "$SETTINGS_SCRIPT"
require_file "$BUILD_SCRIPT"
require_file "$ROUTER_SERVICE_SCRIPT"

SETTINGS_VERSION="$(get_script_version "$SETTINGS_SCRIPT")"
BUILD_VERSION="$(get_script_version "$BUILD_SCRIPT")"
ROUTER_SERVICE_VERSION="$(get_script_version "$ROUTER_SERVICE_SCRIPT")"

info "Running ${SCRIPT_NAME} ${SCRIPT_VERSION}"
echo "LLAMA_DIR: $LLAMA_DIR"
echo "HF_CACHE_DIR: $HF_CACHE_DIR"
echo "Service user: $OWNER_USER"
echo "Service name: $SERVICE_NAME.service"
echo "Resolved child scripts and versions:"
echo "  - $SETTINGS_SCRIPT ${SETTINGS_VERSION:-<unknown>}"
echo "  - $BUILD_SCRIPT ${BUILD_VERSION:-<unknown>}"
echo "  - $ROUTER_SERVICE_SCRIPT ${ROUTER_SERVICE_VERSION:-<unknown>}"

if [[ "$RESET_BAD_TARGET_DEPRECATED" == "true" ]]; then
  warn "--reset-bad-target is deprecated; non-git LLAMA_DIR cleanup is automatic."
fi

if [[ "$STATUS_ONLY" == "true" ]]; then
  print_router_status
  exit 0
fi

if [[ "$FORCE" != "true" && "$BUILD_ONLY" != "true" && "$SERVICE_ONLY" != "true" ]] && router_is_active; then
  if service_has_expected_settings_config; then
    ok "${SERVICE_NAME}.service is already running with expected AI settings. No build or restart was performed."
    print_router_status
    exit 0
  fi
  info "${SERVICE_NAME}.service is running, but AI settings are missing/stale. Continuing to verify build, refresh settings, and rewrite service."
fi

force_reset_if_requested
if [[ "$FORCE" != "true" ]]; then
  cleanup_non_git_llama_dir
fi

if [[ "$SERVICE_ONLY" == "true" ]]; then
  info "[1/2] Running bai1_build_settings.sh ${SETTINGS_VERSION:-<unknown>} ..."
  run_settings_script
  info "[2/2] Running bai1_build_router_service.sh ${ROUTER_SERVICE_VERSION:-<unknown>} ..."
  run_router_service_script
  ok "Done. AI service workflow complete."
  exit 0
fi

if [[ "$BUILD_ONLY" == "true" ]]; then
  info "[1/1] Running bai1_build_llama.sh ${BUILD_VERSION:-<unknown>} foreground ..."
  env LLAMA_DIR="$LLAMA_DIR" bash "$BUILD_SCRIPT"
  ok "Done. AI build workflow complete."
  exit 0
fi

info "[1/3] Running bai1_build_llama.sh ${BUILD_VERSION:-<unknown>} foreground ..."
build_args=()
if [[ "$FORCE" == "true" ]]; then
  build_args+=(--force)
fi
env LLAMA_DIR="$LLAMA_DIR" bash "$BUILD_SCRIPT" "${build_args[@]}"

info "[2/3] Running bai1_build_settings.sh ${SETTINGS_VERSION:-<unknown>} ..."
run_settings_script

info "[3/3] Running bai1_build_router_service.sh ${ROUTER_SERVICE_VERSION:-<unknown>} ..."
run_router_service_script

ok "Done. 0buildai workflow complete."
