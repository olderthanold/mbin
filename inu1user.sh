#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# User-level initialization.
# Scope: optional user cloning.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INITI_DIR="$SCRIPT_DIR/initi"
TARGET_USER="${1:-}"  # Optional cloned user; when empty, clone step is skipped

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

S_CLONE_USER="$INITI_DIR/inu2_clone_user.sh"

for f in \
  "$S_CLONE_USER"; do
  require_file "$f"
done

V_CLONE_USER="$(get_script_version "$S_CLONE_USER")"

if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo), e.g.:${NC}"
  echo "  sudo bash $0 [new_user]"
  exit 1
fi

CURRENT_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"  # Caller user
if [[ -z "$CURRENT_USER" || "$CURRENT_USER" == "root" ]]; then
  CURRENT_USER="ubuntu"  # Fallback user
fi

echo -e "${YELLOW}2. Running inu1user.sh v07 (user setup) for: $CURRENT_USER${NC}"
echo "Resolved initi script base path: $INITI_DIR"
echo "Resolved child script and version:"
echo "  - $S_CLONE_USER ${V_CLONE_USER:-<unknown>}"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
if [[ -n "$TARGET_USER" ]]; then
  echo "2.[1/1] inu2_clone_user.sh ${V_CLONE_USER:-<unknown>} - create '$TARGET_USER' cloned from '$CURRENT_USER' (sudo + home + ssh keys)"
  if id "$TARGET_USER" >/dev/null 2>&1; then
    echo -e "${YELLOW}User '$TARGET_USER' already exists; skipping clone step (idempotent behavior).${NC}"
  else
    bash "$S_CLONE_USER" "$TARGET_USER" "$CURRENT_USER"
  fi
else
  echo "2.[1/1] inu2_clone_user.sh ${V_CLONE_USER:-<unknown>} - skipped (no new username provided)"
fi

echo ""
echo -e "${GREEN}inu1user complete. User-level setup finished.${NC}"
echo "Safe to run again (idempotent where possible)."
