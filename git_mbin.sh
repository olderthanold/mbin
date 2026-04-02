#!/usr/bin/env bash

if [ -d "$HOME"/mbin/.git ]; then  # If repo exists, pull
  git -C "$HOME"/mbin pull origin main
else  # If missing, clone
  git clone -b main https://github.com/olderthanold/mbin.git "$HOME"/mbin
fi
chmod +x "$HOME"/mbin/*.sh  # Make scripts executable
