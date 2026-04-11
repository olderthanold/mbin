#!/usr/bin/env bash
set -euo pipefail

echo "Running git_mbin.sh v02"

MBIN_DIR="/opt/mbin"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

if ! git -C "$MBIN_DIR" pull origin main; then
  echo "Initial pull failed. Trying recovery: stash + pull --rebase"

  recovery_stash_ref=""
  recovery_stash_msg="git_mbin_autostash_$(date +%Y%m%d_%H%M%S)"

  # Stash only when there is local work to save.
  if [[ -n "$(git -C "$MBIN_DIR" status --porcelain)" ]]; then
    git -C "$MBIN_DIR" stash push -u -m "$recovery_stash_msg"
    recovery_stash_ref="$(git -C "$MBIN_DIR" stash list | awk -v msg="$recovery_stash_msg" '$0 ~ msg {print $1; exit}')"
  fi

  if git -C "$MBIN_DIR" pull --rebase origin main; then
    echo "Recovery pull --rebase succeeded."
    if [[ -n "$recovery_stash_ref" ]]; then
      git -C "$MBIN_DIR" stash drop "$recovery_stash_ref" >/dev/null || true
      echo "Dropped recovery stash: $recovery_stash_ref"
    fi
  else
    echo "Recovery pull --rebase failed, recreating $MBIN_DIR"
    rm -rf "$MBIN_DIR"
    git clone -b main https://github.com/olderthanold/mbin.git "$MBIN_DIR"
  fi
fi

chmod +x "$MBIN_DIR"/*.sh 2>/dev/null || true
