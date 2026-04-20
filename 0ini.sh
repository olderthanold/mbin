#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"  # Script dir
TARGET_USER="${1:-}"  # Optional cloned user; when empty, clone step is skipped

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo -e "${RED}Error: required script not found: $f${NC}"
    exit 1
  fi
}

for f in \
  "$SCRIPT_DIR/ini1sys_.sh" \
  "$SCRIPT_DIR/init_1_user.sh"; do
  require_file "$f"
done

if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo), e.g.:${NC}"
  echo "  sudo bash $0"
  exit 1
fi

echo -e "${YELLOW}Running 0ini.sh v04 (ini1sys_ + init_1_user)${NC}"

echo -e "${YELLOW}═════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}[1/2] ini1sys_.sh v12 - server-level setup${NC}"
bash "$SCRIPT_DIR/ini1sys_.sh"

echo -e "${YELLOW}═════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}[2/2] init_1_user.sh v05 - user-level setup${NC}"
bash "$SCRIPT_DIR/init_1_user.sh" "$TARGET_USER"

echo ""
echo -e "${GREEN}0ini complete. Server-level and user-level setup finished.${NC}"
echo "Safe to run again (idempotent where possible)."
