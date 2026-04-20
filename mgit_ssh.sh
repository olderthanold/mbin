#!/usr/bin/env bash
# =============================================================================
# git_mbin_ssh.sh - Automated repository management for /opt/mbin directory
# Purpose: Keeps track of and updates multiple scripts/tools stored in /opt/mbin
# Author: olderthanold (via m.git repository)
# =============================================================================

set -euo pipefail  # Exit on error, undefined variable, or pipeline failure

SCRIPT_NAME="git_mbin_ssh.sh"
SCRIPT_VERSION="v02"
SEP="======================================================================"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}${SEP}${NC}"
echo -e "${YELLOW}Running $SCRIPT_NAME $SCRIPT_VERSION${NC}"
echo -e "${YELLOW}${SEP}${NC}"

MBIN_DIR="/opt/mbin"

# Check if running as root - required for /opt directory access
echo -e "${YELLOW}[1/5] Checking privileges (root required for $MBIN_DIR)${NC}"
if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo).${NC}"
  exit 1
fi

# Pull latest changes from GitHub repository
echo -e "${YELLOW}[2/5] Pulling latest changes (SSH remote) into $MBIN_DIR${NC}"
if ! GIT_SSH_COMMAND="ssh -i /home/ubun2/.ssh/old.key" git -C "$MBIN_DIR" pull git@github.com:olderthanold/mbin.git main; then
  # Recovery mode if initial pull fails
  echo -e "${YELLOW}Initial pull failed. Entering recovery flow: stash + pull --rebase + fallback clone${NC}"

  recovery_stash_ref=""
  recovery_stash_msg="git_gbin_autostash_$(date +%Y%m%d_%H%M%S)"

  # Only stash if there are local changes to preserve
  echo -e "${YELLOW}[3/5] Checking local changes before recovery${NC}"
  if [[ -n "$(git -C "$MBIN_DIR" status --porcelain)" ]]; then
    git -C "$MBIN_DIR" stash push -u -m "$recovery_stash_msg"
    recovery_stash_ref="$(git -C "$MBIN_DIR" stash list | awk -v msg="$recovery_stash_msg" '$0 ~ msg {print $1; exit}')"
    echo -e "${GREEN}Created recovery stash: ${recovery_stash_ref:-<unknown>}${NC}"
  else
    echo -e "${YELLOW}No local changes detected; stash not needed.${NC}"
  fi

  # Try pull with rebase to handle conflicts better
  echo -e "${YELLOW}[4/5] Attempting recovery pull --rebase (SSH remote)${NC}"
  if git -C "$MBIN_DIR" pull --rebase git@github.com:olderthanold/mbin.git main; then
    echo -e "${GREEN}Recovery pull --rebase succeeded.${NC}"
    # Clean up the stash we created
    if [[ -n "$recovery_stash_ref" ]]; then
      git -C "$MBIN_DIR" stash drop "$recovery_stash_ref" >/dev/null || true
      echo -e "${GREEN}Dropped recovery stash: $recovery_stash_ref${NC}"
    fi
  else
    # Last resort: recreate the directory entirely
    echo -e "${YELLOW}Recovery pull --rebase failed, recreating $MBIN_DIR${NC}"
    rm -rf "$MBIN_DIR"
    GIT_SSH_COMMAND="ssh -i /home/ubun2/.ssh/old.key" git clone -b main git@github.com:olderthanold/mbin.git "$MBIN_DIR"
  fi
fi

# Restore executable permissions on all scripts after update
echo -e "${YELLOW}[5/5] Restoring executable permission on shell scripts in $MBIN_DIR${NC}"
chmod +x "$MBIN_DIR"/*.sh 2>/dev/null || true
echo -e "${GREEN}Done: $SCRIPT_NAME workflow complete.${NC}"