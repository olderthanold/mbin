#!/usr/bin/env bash
#Marek: DOES THIS: cd mbin && git pull origin main

# git_mbin_pull.sh
# ----------------
# Purpose:
#   - If local mbin repo does not exist, clone it.
#   - If it exists, update it with a fast-forward pull.
#
# Usage:
#   ./git_mbin_pull.sh
#   ./git_mbin_pull.sh /custom/path/to/mbin

set -euo pipefail

# GitHub repository URL and default branch
REPO_URL="https://github.com/olderthanold/mbin.git"
BRANCH="main"

# Optional first argument = target directory; default is ~/mbin
TARGET_DIR="${1:-$HOME/mbin}"

# If target already contains a Git repo, update it.
if [[ -d "$TARGET_DIR/.git" ]]; then
  echo "Repo exists at $TARGET_DIR, pulling latest..."

  # Prefer origin; fallback to older-m if origin is missing.
  REMOTE_NAME="origin"
  if ! git -C "$TARGET_DIR" remote get-url origin >/dev/null 2>&1; then
    if git -C "$TARGET_DIR" remote get-url older-m >/dev/null 2>&1; then
      REMOTE_NAME="older-m"
    else
      # If neither remote exists, create origin.
      git -C "$TARGET_DIR" remote add origin "$REPO_URL"
    fi
  fi

  # Sync and update main branch without merge commits.
  git -C "$TARGET_DIR" fetch --all --prune
  git -C "$TARGET_DIR" checkout "$BRANCH"
  git -C "$TARGET_DIR" pull --ff-only "$REMOTE_NAME" "$BRANCH"
else
  # Fresh clone path
  echo "Cloning $REPO_URL into $TARGET_DIR..."
  git clone -b "$BRANCH" "$REPO_URL" "$TARGET_DIR"
fi

echo "Done."
