#!/usr/bin/env bash
set -euo pipefail

echo "Running git_web.sh v01"

# Default values (can be overridden by arguments)
DOMAIN="${1:-oldneues.duckdns.org}"
WEB_DIR="/webs/$DOMAIN"
GIT_LINK="${2:-https://github.com/olderthanold/web.git}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

if ! git -C "$WEB_DIR" pull origin main; then
  echo "Initial pull failed. Trying recovery: stash + pull --rebase"

  recovery_stash_ref=""
  recovery_stash_msg="git_mbin_autostash_$(date +%Y%m%d_%H%M%S)"

  # Stash only when there is local work to save.
  if [[ -n "$(git -C "$WEB_DIR" status --porcelain)" ]]; then
    git -C "$WEB_DIR" stash push -u -m "$recovery_stash_msg"
    recovery_stash_ref="$(git -C "$WEB_DIR" stash list | awk -v msg="$recovery_stash_msg" '$0 ~ msg {print $1; exit}')"
  fi

  if git -C "$WEB_DIR" pull --rebase origin main; then
    echo "Recovery pull --rebase succeeded."
    if [[ -n "$recovery_stash_ref" ]]; then
      git -C "$WEB_DIR" stash drop "$recovery_stash_ref" >/dev/null || true
      echo "Dropped recovery stash: $recovery_stash_ref"
    fi
  else
    echo "Recovery pull --rebase failed, recreating $WEB_DIR"
    rm -rf "$WEB_DIR"
    git clone -b main "$GIT_LINK" "$WEB_DIR"
  fi
fi

chmod +x "$WEB_DIR"/*.sh 2>/dev/null || true

