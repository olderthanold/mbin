#!/usr/bin/env bash
# =============================================================================
# git_mbin.sh - Automated repository management for /opt/mbin directory
# Purpose: Keeps track of and updates multiple scripts/tools stored in /opt/mbin
# Author: olderthanold (via m.git repository)
# =============================================================================

set -euo pipefail  # Exit on error, undefined variable, or pipeline failure

echo "Running git_mbin.sh v02"

MBIN_DIR="/opt/mbin"

# Check if running as root - required for /opt directory access
if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

# Pull latest changes from GitHub repository
if ! git -C "$MBIN_DIR" pull git@github.com:olderthanold/m.git main; then
  # Recovery mode if initial pull fails
  
  recovery_stash_ref=""
  recovery_stash_msg="git_gbin_autostash_$(date +%Y%m%d_%H%M%S)"

  # Only stash if there are local changes to preserve
  if [[ -n "$(git -C "$MBIN_DIR" status --porcelain)" ]]; then
    git -C "$MBIN_DIR" stash push -u -m "$recovery_stash_msg"
    recovery_stash_ref="$(git -C "$MBIN_DIR" stash list | awk -v msg="$recovery_stash_msg" '$0 ~ msg {print $1; exit}')"
  fi

  # Try pull with rebase to handle conflicts better
  if git -C "$MBIN_DIR" pull --rebase origin main; then
    echo "Recovery pull --rebase succeeded."
    # Clean up the stash we created
    if [[ -n "$recovery_stash_ref" ]]; then
      git -C "$MBIN_DIR" stash drop "$recovery_stash_ref" >/dev/null || true
      echo "Dropped recovery stash: $recovery_stash_ref"
    fi
  else
    # Last resort: recreate the directory entirely
    echo "Recovery pull --rebase failed, recreating $MBIN_DIR"
    rm -rf "$MBIN_DIR"
    git clone -b main git@github.com:olderthanold/m.git "$MBIN_DIR"
  fi
fi

# Restore executable permissions on all scripts after update
chmod +x "$MBIN_DIR"/*.sh 2>/dev/null || true