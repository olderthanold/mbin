#!/usr/bin/env bash
# mgit_oldssh.sh v05
# =============================================================================
# git_mbin_ssh.sh - Automated repository management for /m/mbin directory
# Purpose: Keeps track of and updates multiple scripts/tools stored in /m/mbin
# Author: olderthanold (via m.git repository)
# =============================================================================

set -euo pipefail  # Exit on error, undefined variable, or pipeline failure

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}======================================================================${NC}"
echo -e "${YELLOW}Running mgit_oldssh.sh - v05"
echo -e "${YELLOW}======================================================================${NC}"

MBIN_DIR="${1:-/m/mbin}"

# Check privilege level; warn only (do not stop if sudo/root is absent).
echo -e "${YELLOW}[1/5] Checking privileges (warning-only mode) for $MBIN_DIR${NC}"
if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${YELLOW}Warning: not running as root; continuing (sudo may not be needed).${NC}"
fi

# Pull latest changes from GitHub repository.
# On any failure, immediately use last resort: recreate and clone fresh.
echo -e "${YELLOW}[2/5] Pulling latest changes (SSH remote) into $MBIN_DIR${NC}"
if ! GIT_SSH_COMMAND="ssh -i /home/ubun2/.ssh/old.key" git -C "$MBIN_DIR" pull git@github.com:olderthanold/mbin.git main; then
  echo -e "${YELLOW}[3/5] Pull failed. Using last resort: recreate and clone fresh.${NC}"
  rm -rf "$MBIN_DIR"
  GIT_SSH_COMMAND="ssh -i /home/ubun2/.ssh/old.key" git clone -b main git@github.com:olderthanold/mbin.git "$MBIN_DIR"
fi

# Restore executable permissions on all scripts after update
echo -e "${YELLOW}[4/5] Restoring executable permission on shell scripts in $MBIN_DIR${NC}"
chmod +x "$MBIN_DIR"/*.sh 2>/dev/null || true

# Final ownership fix for sudo caller:
# If target owner/group are not the sudo user and their primary group,
# enforce that ownership on the whole target directory tree.
echo -e "${YELLOW}[5/5] Ensuring ownership matches sudo user (when running under sudo)${NC}"
if [[ -n "${SUDO_USER:-}" && -d "$MBIN_DIR" ]]; then
  TARGET_OWNER="$(stat -c '%U' "$MBIN_DIR")"
  TARGET_GROUP="$(stat -c '%G' "$MBIN_DIR")"
  SUDO_GROUP="$(id -gn "$SUDO_USER")"

  if [[ "$TARGET_OWNER" != "$SUDO_USER" || "$TARGET_GROUP" != "$SUDO_GROUP" ]]; then
    echo -e "${YELLOW}Ownership mismatch detected ($TARGET_OWNER:$TARGET_GROUP). Applying $SUDO_USER:$SUDO_GROUP${NC}"
    chown -R "$SUDO_USER:$SUDO_GROUP" "$MBIN_DIR"
  else
    echo -e "${GREEN}Ownership already matches sudo user target: $SUDO_USER:$SUDO_GROUP${NC}"
  fi
else
  echo -e "${YELLOW}Not running under sudo (or target missing); skipping sudo ownership enforcement.${NC}"
fi

echo -e "${GREEN}Done: $SCRIPT_NAME workflow complete.${NC}"
