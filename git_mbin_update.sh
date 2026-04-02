#!/usr/bin/env bash

# git_mbin_update.sh
# ------------------
# Purpose:
#   - Update an already cloned mbin repo.
#   - Fast-forward pull only (no merge commits).
#
# Usage:
#   ./git_mbin_update.sh
#   ./git_mbin_update.sh /custom/path/to/mbin

set -euo pipefail

# Optional first argument = target directory; default is ~/mbin
TARGET_DIR="${1:-$HOME/mbin}"

# Preferred remote and branch
REMOTE_NAME="origin"
BRANCH="main"

# Guard: target must already be a git repo
if [[ ! -d "$TARGET_DIR/.git" ]]; then
  echo "Not a git repo: $TARGET_DIR"
  echo "Run git_mbin_pull.sh first."
  exit 1
fi

# Prefer origin; fallback to older-m if origin does not exist.
if ! git -C "$TARGET_DIR" remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  if git -C "$TARGET_DIR" remote get-url older-m >/dev/null 2>&1; then
    REMOTE_NAME="older-m"
  else
    echo "No usable remote found (origin/older-m)."
    exit 1
  fi
fi

# Refresh refs and fast-forward local main to remote main.
git -C "$TARGET_DIR" fetch --all --prune
git -C "$TARGET_DIR" checkout "$BRANCH"
git -C "$TARGET_DIR" pull --ff-only "$REMOTE_NAME" "$BRANCH"

echo "Updated $TARGET_DIR from $REMOTE_NAME/$BRANCH"
