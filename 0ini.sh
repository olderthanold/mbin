#!/usr/bin/env bash
# 0ini.sh v08
set -euo pipefail  # Stop on errors/unset vars

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_NAME="0ini.sh"
SCRIPT_VERSION="v08"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"  # Script dir
S_INI1="$SCRIPT_DIR/ini1sys.sh"
S_USER="$SCRIPT_DIR/inu1user.sh"

show_help() {
  cat <<EOF
Usage: $0 [target_user]

Runs the system/user initialization workflow:
  1. Run ini1sys.sh for server-level setup.
  2. Run inu1user.sh for user-level setup and optional user clone.

Run this wrapper without sudo/root. It asks for sudo only for system-level child steps.

Arguments:
  target_user    Optional cloned user. When omitted, clone step is skipped.

Examples:
  bash $0
  bash $0 emp
EOF
}

fail() {
  echo -e "${RED}ERROR: $*${NC}" >&2
  exit 1
}

info() {
  echo -e "${YELLOW}$*${NC}"
}

ok() {
  echo -e "${GREEN}$*${NC}"
}

refuse_root_invocation() {
  if [[ "$EUID" -eq 0 ]]; then
    echo -e "${RED}ERROR: Do not run ${SCRIPT_NAME} with sudo/root.${NC}" >&2
    echo -e "${YELLOW}Run it as your normal user; sudo is requested only for system-level child steps.${NC}" >&2
    echo >&2
    show_help
    exit 1
  fi
}

run_root() {
  if [[ "$EUID" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

require_file() {
  local f="$1"
  [[ -f "$f" ]] || fail "required script not found: $f"
}

get_script_version() {
  local script_path="$1"
  local v
  v="$(grep -Eom1 '^# [[:alnum:]_.-]+ v[0-9]+|Running [[:alnum:]_.-]+ v[0-9]+' "$script_path" | grep -Eo 'v[0-9]+' | head -n1 || true)"
  echo "$v"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

refuse_root_invocation

if [[ "$#" -gt 1 ]]; then
  show_help
  exit 1
fi

TARGET_USER="${1:-}"  # Optional cloned user; when empty, clone step is skipped

for f in \
  "$S_INI1" \
  "$S_USER"; do
  require_file "$f"
done

V_INI1="$(get_script_version "$S_INI1")"
V_USER="$(get_script_version "$S_USER")"

info "Running ${SCRIPT_NAME} ${SCRIPT_VERSION} (ini1sys + inu1user)"
echo "Resolved child scripts and versions:"
echo "  - $S_INI1 ${V_INI1:-<unknown>}"
echo "  - $S_USER ${V_USER:-<unknown>}"

info "═════════════════════════════════════════════════════════════════════════"
info "[1/2] ini1sys.sh ${V_INI1:-<unknown>} - server-level setup"
run_root bash "$S_INI1"

info "═════════════════════════════════════════════════════════════════════════"
info "[2/2] inu1user.sh ${V_USER:-<unknown>} - user-level setup"
if [[ -n "$TARGET_USER" ]]; then
  run_root bash "$S_USER" "$TARGET_USER"
else
  run_root bash "$S_USER"
fi

echo ""
ok "0ini complete. Server-level and user-level setup finished."
echo "Safe to run again (idempotent where possible)."
