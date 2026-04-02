#!/usr/bin/env bash
if ! git -C "$HOME"/mbin pull origin main; then  # Try update
  echo "Pull failed, recreating ~/mbin"  # Fallback notice
  cd "$HOME"  # Avoid deleting current dir
  rm -rf "$HOME"/mbin  # Remove broken/missing repo
  git clone -b main https://github.com/olderthanold/mbin.git "$HOME"/mbin  # Fresh clone
fi
chmod +x "$HOME"/mbin/*.sh 2>/dev/null || true  # Keep sh exec
