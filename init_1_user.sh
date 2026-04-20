#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# User-level initialization.
# Scope: optional user cloning.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${1:-}"  # Optional cloned user; when empty, clone step is skipped

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo -e "${RED}Error: required script not found: $f${NC}"
    exit 1
  fi
}

for f in \
  "$SCRIPT_DIR/init_2_user_clone_user.sh"; do
  require_file "$f"
done

if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo), e.g.:${NC}"
  echo "  sudo bash $0 [new_user]"
  exit 1
fi

CURRENT_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"  # Caller user
if [[ -z "$CURRENT_USER" || "$CURRENT_USER" == "root" ]]; then
  CURRENT_USER="ubuntu"  # Fallback user
fi

echo -e "${YELLOW}2. Running init_1_user.sh v05 (user setup) for: $CURRENT_USER${NC}"

echo -e "${YELLOW}_________________________________________________________________________${NC}"
if [[ -n "$TARGET_USER" ]]; then
  echo "2.[1/1] init_2_user_clone_user.sh v02 - create '$TARGET_USER' cloned from '$CURRENT_USER' (sudo + home + ssh keys)"
  if id "$TARGET_USER" >/dev/null 2>&1; then
    echo -e "${YELLOW}User '$TARGET_USER' already exists; skipping clone step (idempotent behavior).${NC}"
  else
    bash "$SCRIPT_DIR/init_2_user_clone_user.sh" "$TARGET_USER" "$CURRENT_USER"
  fi
else
  echo "2.[1/1] init_2_user_clone_user.sh v02 - skipped (no new username provided)"
fi

echo ""
echo -e "${GREEN}init_1_user complete. User-level setup finished.${NC}"
echo "Safe to run again (idempotent where possible)."
