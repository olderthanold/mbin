#!/usr/bin/env bash

if [ -d "$HOME"/mbin/.git ]; then  # If repo exists, pull
  if ! git -C "$HOME"/mbin pull origin main; then
    echo "pull failed"
    rm -rf "$HOME"/mbin/.git
    git clone -b main https://github.com/olderthanold/mbin.git "$HOME"/mbin
  fi
else  # If missing, clone
  git clone -b main https://github.com/olderthanold/mbin.git "$HOME"/mbin
fi
chmod +x "$HOME"/mbin/*.sh  # Make scripts executable
