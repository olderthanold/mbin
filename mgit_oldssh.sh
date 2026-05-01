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
echo -e "${YELLOW}Running mgit_oldssh.sh v07"
echo -e "${YELLOW}Takes target as an argument, default: /m/mbin"
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

# Pull latest changes from GitHub repository.
# On any failure, immediately use last resort: recreate and clone fresh.
echo -e "${YELLOW}[3/6] Pulling latest changes (SSH remote) into $MBIN_DIR${NC}"
if ! GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH" git -C "$MBIN_DIR" pull git@github.com:olderthanold/mbin.git main; then
  echo -e "${YELLOW}[4/6] Pull failed. Using last resort: recreate and clone fresh.${NC}"
  rm -rf "$MBIN_DIR"
  GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH" git clone -b main git@github.com:olderthanold/mbin.git "$MBIN_DIR"
fi

# Restore executable permissions on all scripts after update
echo -e "${YELLOW}[5/6] Restoring executable permission on shell scripts in $MBIN_DIR${NC}"
chmod +x "$MBIN_DIR"/*.sh 2>/dev/null || true

# Final ownership fix for sudo caller:
# If target owner/group are not the sudo user and their primary group,
# enforce that ownership on the whole target directory tree.
echo -e "${YELLOW}[6/6] Ensuring ownership matches sudo user (when running under sudo)${NC}"
if [[ -n "${SUDO_USER:-}" && -d "$MBIN_DIR" ]]; then
  TARGET_OWNER="$(stat -c '%U' "$MBIN_DIR")"
  TARGET_GROUP="$(stat -c '%G' "$MBIN_DIR")"
  SUDO_GROUP="$(id -gn "$SUDO_USER")"

  if [[ "$TARGET_OWNER" != "$SUDO_USER" || "$TARGET_GROUP" != "$SUDO_GROUP" ]]; then
    echo -e "${YELLOW}Ownership mismatch detected ($TARGET_OWNER:$TARGET_GROUP). Applying $SUDO_USER:$SUDO_GROUP${NC}"
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

echo -e "${GREEN}Done: $SCRIPT_NAME workflow complete.${NC}"
