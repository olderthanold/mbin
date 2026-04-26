#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# llama_systemd_service.sh
# Creates and enables a systemd unit for llama.cpp server bound to localhost.
#
# Why this script:
# - Keeps nginx on public 80/443
# - Runs llama-server privately on 127.0.0.1:8080
# - Avoids port-80 conflict on low-resource VM
# ==============================================================================

# ----- Colors for human-friendly progress logs -----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ----- Configurable values (edit if needed) -----
SERVICE_NAME="llama-server"
LLAMA_USER="ubun2"
LLAMA_WORKDIR="/home/ubun2/ai/llama.cpp"
LLAMA_BIN="/home/ubun2/ai/llama.cpp/build/bin/llama-server"

# Model source on Hugging Face and exact GGUF filename.
MODEL_HF="ZuzeTt/LFM2.5-VL-450M-GGUF"
MODEL_FILE="LFM2.5-VL-450M-imatrix-Q8_0.gguf"

# Backend bind stays local-only (safe behind nginx reverse proxy).
BIND_HOST="127.0.0.1"
BIND_PORT="8080"

# Generation/runtime options.
CTX_SIZE="8192"          # -c : context window tokens
TEMPERATURE="0.7"        # --temp : randomness
REPEAT_PENALTY="1.05"    # --repeat-penalty : lower token repetition loops

# Optional script mode:
#   --write-only  -> writes unit and daemon-reload only (does not start service)
WRITE_ONLY="false"
if [[ "${1:-}" == "--write-only" ]]; then
  WRITE_ONLY="true"
fi

echo -e "${YELLOW}[0/6] Pre-flight checks...${NC}"

# Check required binaries before proceeding.
if ! command -v sudo >/dev/null 2>&1; then
  echo -e "${RED}ERROR: 'sudo' not found in PATH.${NC}"
  exit 1
fi

if [[ ! -x "${LLAMA_BIN}" ]]; then
  echo -e "${RED}ERROR: llama binary not found/executable at:${NC} ${LLAMA_BIN}"
  echo -e "${YELLOW}Hint: build llama.cpp first or adjust LLAMA_BIN in this script.${NC}"
  exit 1
fi

echo -e "${YELLOW}[1/6] Writing /etc/systemd/system/${SERVICE_NAME}.service ...${NC}"
sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" >/dev/null <<EOF_SERVICE
[Unit]
Description=llama.cpp server (${MODEL_FILE})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${LLAMA_USER}
WorkingDirectory=${LLAMA_WORKDIR}
ExecStart=${LLAMA_BIN} \\
  -hf ${MODEL_HF} \\
  -hff ${MODEL_FILE} \\
  --reasoning off \\
  --temp ${TEMPERATURE} \\
  --no-mmproj \\
  --jinja \\
  --repeat-penalty ${REPEAT_PENALTY} \\
  -c ${CTX_SIZE} \\
  --host ${BIND_HOST} \\
  --port ${BIND_PORT}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF_SERVICE

echo -e "${YELLOW}[2/6] Reloading systemd manager configuration...${NC}"
sudo systemctl daemon-reload

if [[ "${WRITE_ONLY}" == "true" ]]; then
  echo -e "${GREEN}Write-only mode complete.${NC}"
  echo -e "${YELLOW}Next commands:${NC}"
  echo "  sudo systemctl enable --now ${SERVICE_NAME}.service"
  echo "  sudo systemctl status ${SERVICE_NAME}.service --no-pager"
  exit 0
fi

echo -e "${YELLOW}[3/6] Enabling service on boot and starting now...${NC}"
sudo systemctl enable --now "${SERVICE_NAME}.service"

echo -e "${YELLOW}[4/6] Showing current service status...${NC}"
sudo systemctl status "${SERVICE_NAME}.service" --no-pager

echo -e "${YELLOW}[5/6] Local HTTP check against ${BIND_HOST}:${BIND_PORT} ...${NC}"
curl -sS "http://${BIND_HOST}:${BIND_PORT}/" | head -n 5 || true

echo -e "${YELLOW}[6/6] Local health check...${NC}"
curl -sS "http://${BIND_HOST}:${BIND_PORT}/health" || true

echo
echo -e "${GREEN}Done. llama-server is managed by systemd.${NC}"
echo -e "${YELLOW}Useful commands:${NC}"
echo "  sudo systemctl stop ${SERVICE_NAME}.service"
echo "  sudo systemctl disable ${SERVICE_NAME}.service"
echo "  sudo systemctl restart ${SERVICE_NAME}.service"
echo "  sudo journalctl -u ${SERVICE_NAME}.service -n 100 --no-pager"
