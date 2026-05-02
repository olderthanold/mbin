#!/usr/bin/env bash
# =============================================================================
# mgit_oldssh.sh - Automated repository management for /m/mbin directory
# Purpose: Pulls updates multple scripts/tools stored in /m/mbin
# Author: olderthanold (via m.git repository)
# =============================================================================

set -euo pipefail  # Exit on error, undefined variable, or pipeline failure

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
SSH_KEY_PATH="/home/ubun2/.ssh/old.key"
MBIN_DIR="${1:-/m/mbin}"
PARENT_DIR="$(dirname "$MBIN_DIR")"

echo -e "${YELLOW}======================================================================${NC}"
echo -e "${YELLOW}Running mgit_oldssh.sh v10"
echo -e "${YELLOW}Takes target dir as an argument, default: /m/mbin"
echo -e "${YELLOW}======================================================================${NC}"

echo -e "${YELLOW}[2/6] Checking SSH key: $SSH_KEY_PATH${NC}"
if [[ ! -f "$SSH_KEY_PATH" || ! -r "$SSH_KEY_PATH" ]]; then
  echo -e "${RED}Error: SSH key missing or not readable: $SSH_KEY_PATH${NC}"
  exit 1
fi

if [[ "$(stat -c '%a' "$SSH_KEY_PATH")" != "600" ]]; then
  echo -e "${RED}Error: SSH key permissions must be 600: $SSH_KEY_PATH${NC}"
  exit 1
fi

if [[ -z "$MBIN_DIR" || "$MBIN_DIR" == "/" || "$MBIN_DIR" == "/m" ]]; then
  echo -e "${RED}Error: refusing unsafe target path: ${MBIN_DIR:-<empty>}${NC}"
  exit 1
fi

# Pull latest changes from GitHub repository. On any failure, recreate and clone fresh.
echo -e "${YELLOW}[3/6] Pulling latest changes (SSH remote) into $MBIN_DIR${NC}"
if ! GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH" git -C "$MBIN_DIR" pull git@github.com:olderthanold/mbin.git main; then
  echo -e "${YELLOW}[4/6] Pull failed. Using last resort: recreate and clone fresh.${NC}"
  rm -rf "$MBIN_DIR"
  GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH" git clone -b main git@github.com:olderthanold/mbin.git "$MBIN_DIR"
fi

echo -e "${YELLOW}[3/4] Restoring executable permission on shell scripts in $MBIN_DIR${NC}"
chmod +x "$MBIN_DIR"/*.sh 2>/dev/null || true

echo -e "${YELLOW}[4/4] Ensuring ownership matches sudo user when available${NC}"
if [[ -n "${SUDO_USER:-}" && -d "$MBIN_DIR" ]]; then
  TARGET_UID="$(stat -c '%u' "$MBIN_DIR")"
  TARGET_GID="$(stat -c '%g' "$MBIN_DIR")"
  SUDO_UID_NUM="$(id -u "$SUDO_USER")"
  SUDO_GID_NUM="$(id -g "$SUDO_USER")"
  SUDO_GROUP="$(id -gn "$SUDO_USER")"

  if [[ "$TARGET_UID" != "$SUDO_UID_NUM" || "$TARGET_GID" != "$SUDO_GID_NUM" ]]; then
    echo -e "${YELLOW}Ownership mismatch detected. Applying $SUDO_USER:$SUDO_GROUP${NC}"
    chown -R "$SUDO_USER:$SUDO_GROUP" "$MBIN_DIR"
    chmod u+rwx,g+rwx "$PARENT_DIR"
    chown -R "$SUDO_USER:$SUDO_GROUP" "$PARENT_DIR"
    chmod u+rwx,g+rwx "$PARENT_DIR"
  else
    echo -e "${GREEN}Ownership already matches sudo user target: $SUDO_USER:$SUDO_GROUP${NC}"
  fi
else
  echo -e "${YELLOW}Not running under sudo (or target missing); skipping sudo ownership enforcement.${NC}"
fi

echo -e "${GREEN}Done: mgit_oldhttps.sh workflow complete.${NC}"
