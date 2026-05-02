#!/usr/bin/env bash
# bai1_build_router_service.sh v08
set -euo pipefail

# Creates and starts a systemd service for llama.cpp router mode.
# The router exposes one HTTP server and loads model profiles on demand.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MBIN_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

SERVICE_NAME="${SERVICE_NAME:-llama-router}"
LLAMA_USER="${LLAMA_USER:-${SUDO_USER:-$(id -un)}}"
LLAMA_GROUP="$(id -gn "${LLAMA_USER}" 2>/dev/null || echo "${LLAMA_USER}")"
LLAMA_WORKDIR="${LLAMA_WORKDIR:-/m/llama.cpp}"
LLAMA_BIN="${LLAMA_BIN:-/m/llama.cpp/build/bin/llama-server}"
LLAMA_BIN_DIR="$(dirname -- "${LLAMA_BIN}")"
MODELS_PRESET="${MODELS_PRESET:-${SCRIPT_DIR}/llama_models.ini}"
ROUTER_MODELS_DIR="${ROUTER_MODELS_DIR:-/m/llama-router-models}"
LLAMA_CONTROL_SCRIPT="${LLAMA_CONTROL_SCRIPT:-${MBIN_DIR}/lctl.sh}"
SETTINGS_ENV_FILE="${SETTINGS_ENV_FILE:-/etc/default/${SERVICE_NAME}}"
BIND_HOST="${BIND_HOST:-0.0.0.0}"
BIND_PORT="${BIND_PORT:-8080}"
MODELS_MAX="${MODELS_MAX:-1}"
SLEEP_IDLE_SECONDS="${SLEEP_IDLE_SECONDS:-900}"

WRITE_ONLY="false"
if [[ "${1:-}" == "--write-only" ]]; then
  WRITE_ONLY="true"
fi

fail() {
  echo -e "${RED}ERROR: $*${NC}" >&2
  exit 1
}

ok() {
  echo -e "${GREEN}OK: $*${NC}"
}

warn() {
  echo -e "${YELLOW}WARN: $*${NC}"
}

run_as_llama_user() {
  if [[ "${EUID}" -eq 0 && "${LLAMA_USER}" != "root" ]]; then
    sudo -u "${LLAMA_USER}" "$@"
  else
    "$@"
  fi
}

validate_router_models_dir() {
  case "${ROUTER_MODELS_DIR}" in
    ""|"/"|"."|".."|"/m"|"/m/"|"/home"|"/home/"|"/root"|"/root/"|"/usr"|"/usr/"|"/opt"|"/opt/"|"/var"|"/var/")
      fail "refusing unsafe ROUTER_MODELS_DIR: ${ROUTER_MODELS_DIR:-<empty>}"
      ;;
    /*)
      ;;
    *)
      fail "ROUTER_MODELS_DIR must be an absolute path: ${ROUTER_MODELS_DIR}"
      ;;
  esac
}

ensure_router_models_dir() {
  local first_gguf

  validate_router_models_dir
  echo -e "${YELLOW}Ensuring router models directory is present and clean:${NC} ${ROUTER_MODELS_DIR}"
  sudo mkdir -p "${ROUTER_MODELS_DIR}"
  sudo chown "${LLAMA_USER}:${LLAMA_GROUP}" "${ROUTER_MODELS_DIR}" 2>/dev/null || true
  sudo chmod 0775 "${ROUTER_MODELS_DIR}" 2>/dev/null || true

  first_gguf="$(find "${ROUTER_MODELS_DIR}" -type f -iname '*.gguf' -print -quit 2>/dev/null || true)"
  if [[ -n "${first_gguf}" ]]; then
    fail "ROUTER_MODELS_DIR contains GGUF files that would appear in Web UI: ${first_gguf}"
  fi

  ok "Router model discovery directory has no GGUF files."
}

runpath_entries() {
  command -v readelf >/dev/null 2>&1 || return 0
  readelf -d "${LLAMA_BIN}" 2>/dev/null |
    awk -F'[][]' '/RPATH|RUNPATH/ {print $2}' |
    tr ':' '\n' |
    sed '/^$/d'
}

runpath_has_origin_or_current_bin_dir() {
  local entry
  while IFS= read -r entry; do
    case "${entry}" in
      *'$ORIGIN'*)
        return 0
        ;;
    esac

    if [[ "${entry}" == "${LLAMA_BIN_DIR}" ]]; then
      return 0
    fi
  done < <(runpath_entries)

  return 1
}

legacy_llama_dir_from_runpath() {
  local entry
  while IFS= read -r entry; do
    case "${entry}" in
      /*/ai/llama.cpp/build/bin)
        printf '%s\n' "${entry%/build/bin}"
        return 0
        ;;
    esac
  done < <(runpath_entries)

  return 1
}

print_runpath_entries() {
  local entries
  entries="$(runpath_entries || true)"

  if [[ -n "${entries}" ]]; then
    printf '%s\n' "${entries}" | sed 's/^/  - /'
  elif command -v readelf >/dev/null 2>&1; then
    echo "  <none>"
  else
    echo "  <readelf not available>"
  fi
}

ensure_legacy_runpath_symlink() {
  local legacy_llama_dir="$1"
  local target_dir="${LLAMA_WORKDIR}"
  local parent_dir
  local current_target
  local resolved_target
  local resolved_legacy

  case "${legacy_llama_dir}" in
    /*/ai/llama.cpp)
      ;;
    *)
      fail "refusing unsafe legacy RUNPATH target: ${legacy_llama_dir}"
      ;;
  esac

  parent_dir="$(dirname -- "${legacy_llama_dir}")"
  resolved_target="$(readlink -f "${target_dir}" 2>/dev/null || printf '%s\n' "${target_dir}")"

  if [[ -L "${legacy_llama_dir}" ]]; then
    current_target="$(readlink "${legacy_llama_dir}")"
    resolved_legacy="$(readlink -f "${legacy_llama_dir}" 2>/dev/null || true)"

    if [[ "${current_target}" == "${target_dir}" || "${resolved_legacy}" == "${resolved_target}" ]]; then
      ok "Compatibility symlink already exists: ${legacy_llama_dir} -> ${current_target}"
      return 0
    fi

    fail "legacy RUNPATH symlink exists but points elsewhere: ${legacy_llama_dir} -> ${current_target}"
  fi

  if [[ -e "${legacy_llama_dir}" ]]; then
    fail "legacy RUNPATH path exists and is not a symlink: ${legacy_llama_dir}"
  fi

  if [[ ! -d "${parent_dir}" ]]; then
    echo "Creating legacy RUNPATH parent directory: ${parent_dir}"
    sudo mkdir -p "${parent_dir}"
    sudo chown "${LLAMA_USER}:${LLAMA_GROUP}" "${parent_dir}" 2>/dev/null || true
  fi

  echo "Creating compatibility symlink for stale RUNPATH: ${legacy_llama_dir} -> ${target_dir}"
  sudo ln -s "${target_dir}" "${legacy_llama_dir}"
  sudo chown -h "${LLAMA_USER}:${LLAMA_GROUP}" "${legacy_llama_dir}" 2>/dev/null || true
}

SMOKE_OUTPUT=""
smoke_llama_binary() {
  local binary_path="$1"
  local version_output
  local help_output

  SMOKE_OUTPUT=""

  if version_output="$(run_as_llama_user "${binary_path}" --version 2>&1)"; then
    ok "Smoke test passed: ${binary_path} --version"
    return 0
  fi

  if help_output="$(run_as_llama_user "${binary_path}" --help 2>&1)"; then
    ok "Smoke test passed: ${binary_path} --help"
    return 0
  fi

  SMOKE_OUTPUT="${version_output}"
  if [[ -n "${help_output:-}" ]]; then
    SMOKE_OUTPUT+=$'\n'"${help_output}"
  fi
  return 1
}

verify_llama_runtime() {
  local legacy_llama_dir

  echo -e "${YELLOW}Smoke testing llama-server runtime as ${LLAMA_USER}...${NC}"
  if smoke_llama_binary "${LLAMA_BIN}"; then
    return 0
  fi

  echo -e "${RED}llama-server smoke test failed:${NC}" >&2
  printf '%s\n' "${SMOKE_OUTPUT}" >&2
  echo -e "${YELLOW}RUNPATH/RPATH entries for ${LLAMA_BIN}:${NC}"
  print_runpath_entries

  if runpath_has_origin_or_current_bin_dir; then
    fail "llama-server cannot run even though RUNPATH contains \$ORIGIN or current binary directory. Clean maintenance fix: sudo bash /m/mbin/0buildai.sh --force"
  fi

  legacy_llama_dir="$(legacy_llama_dir_from_runpath || true)"
  if [[ -z "${legacy_llama_dir}" ]]; then
    fail "no supported legacy RUNPATH ending in /ai/llama.cpp/build/bin was found. Clean maintenance fix: sudo bash /m/mbin/0buildai.sh --force"
  fi

  warn "Detected stale llama.cpp RUNPATH; attempting compatibility symlink autoheal."
  ensure_legacy_runpath_symlink "${legacy_llama_dir}"

  echo -e "${YELLOW}Retrying llama-server smoke test after compatibility symlink...${NC}"
  if smoke_llama_binary "${LLAMA_BIN}"; then
    warn "Compatibility symlink active for stale RUNPATH."
    warn "Clean maintenance fix: sudo bash /m/mbin/0buildai.sh --force"
    return 0
  fi

  echo -e "${RED}llama-server still cannot run after compatibility symlink:${NC}" >&2
  printf '%s\n' "${SMOKE_OUTPUT}" >&2
  fail "legacy RUNPATH autoheal did not repair llama-server. Clean maintenance fix: sudo bash /m/mbin/0buildai.sh --force"
}

echo -e "${YELLOW}Running bai1_build_router_service.sh v08${NC}"
echo -e "${YELLOW}[0/7] Pre-flight checks...${NC}"

if ! command -v sudo >/dev/null 2>&1; then
  echo -e "${RED}ERROR: sudo not found in PATH.${NC}"
  exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo -e "${RED}ERROR: systemctl not found in PATH.${NC}"
  exit 1
fi

if ! id "${LLAMA_USER}" >/dev/null 2>&1; then
  echo -e "${RED}ERROR: service user does not exist:${NC} ${LLAMA_USER}"
  exit 1
fi

if [[ ! -x "${LLAMA_BIN}" ]]; then
  echo -e "${RED}ERROR: llama-server binary not found/executable:${NC} ${LLAMA_BIN}"
  echo -e "${YELLOW}Hint: run /m/mbin/ai/bai1_build_llama.sh first, or override LLAMA_BIN.${NC}"
  exit 1
fi

if [[ ! -r "${MODELS_PRESET}" ]]; then
  echo -e "${RED}ERROR: models preset is not readable:${NC} ${MODELS_PRESET}"
  exit 1
fi

if [[ ! -r "${SETTINGS_ENV_FILE}" ]]; then
  echo -e "${RED}ERROR: settings env file is not readable:${NC} ${SETTINGS_ENV_FILE}"
  echo -e "${YELLOW}Hint: run /m/mbin/ai/bai1_build_settings.sh first.${NC}"
  exit 1
fi

if [[ ! -r "${LLAMA_CONTROL_SCRIPT}" ]]; then
  echo -e "${YELLOW}WARN: llama control script is not readable; final model list will fall back to raw API:${NC} ${LLAMA_CONTROL_SCRIPT}"
fi

ensure_router_models_dir
verify_llama_runtime

echo "Service name: ${SERVICE_NAME}.service"
echo "Service user: ${LLAMA_USER}"
echo "llama-server: ${LLAMA_BIN}"
echo "Models preset: ${MODELS_PRESET}"
echo "Router models dir: ${ROUTER_MODELS_DIR}"
echo "llama control: ${LLAMA_CONTROL_SCRIPT}"
echo "Settings env file: ${SETTINGS_ENV_FILE}"
echo "Bind: ${BIND_HOST}:${BIND_PORT}"

echo -e "${YELLOW}[1/7] Writing /etc/systemd/system/${SERVICE_NAME}.service ...${NC}"
sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" >/dev/null <<EOF_SERVICE
[Unit]
Description=llama.cpp router server
After=network-online.target
Wants=network-online.target
RequiresMountsFor=/m

[Service]
Type=simple
User=${LLAMA_USER}
WorkingDirectory=${LLAMA_WORKDIR}
EnvironmentFile=-${SETTINGS_ENV_FILE}
ExecStart=${LLAMA_BIN} \\
  --models-dir ${ROUTER_MODELS_DIR} \\
  --models-preset ${MODELS_PRESET} \\
  --host ${BIND_HOST} \\
  --port ${BIND_PORT} \\
  --models-max ${MODELS_MAX} \\
  --no-models-autoload \\
  --sleep-idle-seconds ${SLEEP_IDLE_SECONDS}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF_SERVICE

echo -e "${YELLOW}[2/7] Reloading systemd manager configuration...${NC}"
sudo systemctl daemon-reload

if [[ "${WRITE_ONLY}" == "true" ]]; then
  echo -e "${GREEN}Write-only mode complete.${NC}"
  echo "Run: sudo systemctl enable --now ${SERVICE_NAME}.service"
  exit 0
fi

echo -e "${YELLOW}[3/7] Enabling service on boot...${NC}"
sudo systemctl enable "${SERVICE_NAME}.service" >/dev/null

echo -e "${YELLOW}[4/7] Restarting service to apply current config...${NC}"
sudo systemctl restart "${SERVICE_NAME}.service"

echo -e "${YELLOW}[5/7] Showing service status...${NC}"
sudo systemctl status "${SERVICE_NAME}.service" --no-pager

echo -e "${YELLOW}[6/7] Local health check...${NC}"
curl -sS "http://127.0.0.1:${BIND_PORT}/health" || true
echo

echo -e "${YELLOW}[7/7] Available router models...${NC}"
if [[ -r "${LLAMA_CONTROL_SCRIPT}" ]]; then
  LLAMA_BASE_URL="http://127.0.0.1:${BIND_PORT}" \
    LLAMA_MODELS_PRESET="${MODELS_PRESET}" \
    bash "${LLAMA_CONTROL_SCRIPT}" list || true
else
  curl -sS "http://127.0.0.1:${BIND_PORT}/models" || true
  echo
fi

echo -e "${GREEN}Done. llama router is managed by systemd.${NC}"
echo -e "${YELLOW}Useful commands:${NC}"
echo "  sudo systemctl status ${SERVICE_NAME}.service --no-pager"
echo "  sudo journalctl -u ${SERVICE_NAME}.service -n 100 --no-pager"
echo "  lctl.sh list"
echo "  lctl.sh load lfm25vl450"
echo "  lctl.sh chat lfm25vl450 \"Hello\""
