#!/usr/bin/env bash
# run_build_llama.sh v01
set -euo pipefail

RUN_DIR="${RUN_DIR:-/m/llama.cpp}"
BUILD_SCRIPT="${BUILD_SCRIPT:-/m/mbin/ai/build_llama.sh}"
OWNER_USER="${SUDO_USER:-${USER:-$(whoami)}}"
OWNER_GROUP="$(id -gn "$OWNER_USER" 2>/dev/null || echo "$OWNER_USER")"

if [[ ! -d "$RUN_DIR" ]]; then
  sudo mkdir -p "$RUN_DIR"
  sudo chown "$OWNER_USER:$OWNER_GROUP" "$RUN_DIR"
fi

if [[ ! -w "$RUN_DIR" ]]; then
  sudo chown -R "$OWNER_USER:$OWNER_GROUP" "$RUN_DIR"
fi

cd "$RUN_DIR"
nohup "$BUILD_SCRIPT" > aibuild03.log 2>&1 && touch aibuild_script_completed.txt &
echo $!
