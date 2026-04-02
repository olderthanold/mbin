#!/usr/bin/env bash
if [ -d "$HOME"/mbin/.git ]; then
  if ! git -C "$HOME"/mbin pull origin main; then
    cd "$HOME"
    rm -rf "$HOME"/mbin
    git clone -b main https://github.com/olderthanold/mbin.git "$HOME"/mbin
  fi
elif [ -d "$HOME"/mbin ]; then
  cd "$HOME"
  rm -rf "$HOME"/mbin
  git clone -b main https://github.com/olderthanold/mbin.git "$HOME"/mbin
else
  git clone -b main https://github.com/olderthanold/mbin.git "$HOME"/mbin
fi
chmod +x "$HOME"/mbin/*.sh 2>/dev/null || true
