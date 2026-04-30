#!/usr/bin/env bash
# run_build_llama.sh v02
set -euo pipefail

LLAMA_DIR="${LLAMA_DIR:-/m/llama.cpp}"
BUILD_SCRIPT="${BUILD_SCRIPT:-/m/mbin/ai/build_llama.sh}"
LOG_DIR="${LOG_DIR:-/m/aibuild}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/aibuild03.log}"
DONE_FILE="${DONE_FILE:-$LOG_DIR/aibuild_script_completed.txt}"
PID_FILE="${PID_FILE:-$LOG_DIR/aibuild.pid}"
OWNER_USER="${SUDO_USER:-${USER:-$(whoami)}}"
OWNER_GROUP="$(id -gn "$OWNER_USER" 2>/dev/null || echo "$OWNER_USER")"
RESET_BAD_TARGET="false"

show_help() {
  cat <<EOF
Usage: $0 [--reset-bad-target]

Runs build_llama.sh detached through nohup.

Defaults:
  LLAMA_DIR=$LLAMA_DIR
  BUILD_SCRIPT=$BUILD_SCRIPT
  LOG_FILE=$LOG_FILE

Options:
  --reset-bad-target  Remove LLAMA_DIR only when it exists, is not a git repo,
                      and contains only known wrapper/build marker files.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset-bad-target)
      RESET_BAD_TARGET="true"
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      show_help >&2
      exit 1
      ;;
  esac
done

is_known_bad_target() {
  [[ -d "$LLAMA_DIR" ]] || return 1
  [[ ! -d "$LLAMA_DIR/.git" ]] || return 1

  local unexpected
  unexpected="$(find "$LLAMA_DIR" -mindepth 1 -maxdepth 1 \
    ! -name aibuild03.log \
    ! -name aibuild.log \
    ! -name aibuild.pid \
    ! -name aibuild_script_completed.txt \
    -print -quit 2>/dev/null || true)"

  [[ -z "$unexpected" ]]
}

if [[ ! -x "$BUILD_SCRIPT" ]]; then
  echo "Error: build script is not executable: $BUILD_SCRIPT" >&2
  exit 1
fi

if [[ "$RESET_BAD_TARGET" == "true" && -d "$LLAMA_DIR" && ! -d "$LLAMA_DIR/.git" ]]; then
  if is_known_bad_target; then
    echo "Removing known bad non-git LLAMA_DIR: $LLAMA_DIR"
    sudo rm -rf "$LLAMA_DIR"
  else
    echo "Error: refusing to remove non-git LLAMA_DIR with unknown content: $LLAMA_DIR" >&2
    echo "Inspect it manually, then remove it yourself if it is disposable." >&2
    exit 1
  fi
fi

sudo mkdir -p "$LOG_DIR"
sudo chown "$OWNER_USER:$OWNER_GROUP" "$LOG_DIR"
chmod 775 "$LOG_DIR"
rm -f "$DONE_FILE"

nohup env LLAMA_DIR="$LLAMA_DIR" "$BUILD_SCRIPT" > "$LOG_FILE" 2>&1 && touch "$DONE_FILE" &
pid="$!"
printf '%s\n' "$pid" > "$PID_FILE"

echo "$pid"
echo "Log: $LOG_FILE"
echo "Done marker: $DONE_FILE"
