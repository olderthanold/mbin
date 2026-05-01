#!/usr/bin/env bash
# bai1_build_router_service.sh v04
set -euo pipefail

# Creates and starts a systemd service for llama.cpp router mode.
# The router exposes one HTTP server and loads model profiles on demand.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVICE_NAME="${SERVICE_NAME:-llama-router}"
LLAMA_USER="${LLAMA_USER:-${SUDO_USER:-$(id -un)}}"
LLAMA_WORKDIR="${LLAMA_WORKDIR:-/m/llama.cpp}"
LLAMA_BIN="${LLAMA_BIN:-/m/llama.cpp/build/bin/llama-server}"
MODELS_PRESET="${MODELS_PRESET:-${SCRIPT_DIR}/llama_models.ini}"
LLAMA_CONTROL_SCRIPT="${LLAMA_CONTROL_SCRIPT:-${SCRIPT_DIR}/llama_control.sh}"
SETTINGS_ENV_FILE="${SETTINGS_ENV_FILE:-/etc/default/${SERVICE_NAME}}"
BIND_HOST="${BIND_HOST:-0.0.0.0}"
BIND_PORT="${BIND_PORT:-8080}"
MODELS_MAX="${MODELS_MAX:-1}"
SLEEP_IDLE_SECONDS="${SLEEP_IDLE_SECONDS:-900}"

WRITE_ONLY="false"
if [[ "${1:-}" == "--write-only" ]]; then
  WRITE_ONLY="true"
fi

echo -e "${YELLOW}Running bai1_build_router_service.sh v04${NC}"
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

echo "Service name: ${SERVICE_NAME}.service"
echo "Service user: ${LLAMA_USER}"
echo "llama-server: ${LLAMA_BIN}"
echo "Models preset: ${MODELS_PRESET}"
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
echo "  bash /m/mbin/ai/llama_control.sh list"
echo "  bash /m/mbin/ai/llama_control.sh load lfm25vl450"
echo "  bash /m/mbin/ai/llama_control.sh chat lfm25vl450 \"Hello\""
