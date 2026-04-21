#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"  # Script dir
TARGET_USER="${1:-}"  # Optional cloned user; when empty, clone step is skipped
S_INI1="$SCRIPT_DIR/ini1sys.sh"
S_USER="$SCRIPT_DIR/inu1user.sh"

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo -e "${RED}Error: required script not found: $f${NC}"
    exit 1
  fi
}

get_script_version() {
  local script_path="$1"
  local v
  v="$(grep -Eom1 '^# [[:alnum:]_.-]+ v[0-9]+|Running [[:alnum:]_.-]+ v[0-9]+' "$script_path" | grep -Eo 'v[0-9]+' | head -n1 || true)"
  echo "$v"
}

for f in \
  "$S_INI1" \
  "$S_USER"; do
  require_file "$f"
done

V_INI1="$(get_script_version "$S_INI1")"
V_USER="$(get_script_version "$S_USER")"

if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo), e.g.:${NC}"
  echo "  sudo bash $0"
  exit 1
fi

echo -e "${YELLOW}Running 0ini.sh v07 (ini1sys + inu1user)${NC}"
echo "Resolved child scripts and versions:"
echo "  - $S_INI1 ${V_INI1:-<unknown>}"
echo "  - $S_USER ${V_USER:-<unknown>}"

echo -e "${YELLOW}═════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}[1/2] ini1sys.sh ${V_INI1:-<unknown>} - server-level setup${NC}"
bash "$S_INI1"

echo -e "${YELLOW}═════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}[2/2] inu1user.sh ${V_USER:-<unknown>} - user-level setup${NC}"
bash "$S_USER" "$TARGET_USER"

echo ""
echo -e "${GREEN}0ini complete. Server-level and user-level setup finished.${NC}"
echo "Safe to run again (idempotent where possible)."
