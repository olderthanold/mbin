#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"  # Script dir
TARGET_USER="${1:-}"  # Optional cloned user; when empty, clone step is skipped

print_sep() {
  printf '================================================================================\n'
}

print_center_equals() {
  local title="$1"
  local width=80
  local content=" ${title} "

  if (( ${#content} >= width )); then
    printf '%s\n' "$title"
    return
  fi

  local pad_total=$((width - ${#content}))
  local left=$((pad_total / 2))
  local right=$((pad_total - left))

  printf '%*s%s%*s\n' "$left" '' "$content" "$right" '' | tr ' ' '='
}

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "Error: required script not found: $f"
    exit 1
  fi
}

for f in \
  "$SCRIPT_DIR/initinst.sh" \
  "$SCRIPT_DIR/initusr.sh"; do
  require_file "$f"
done

if [[ "$EUID" -ne 0 ]]; then
  echo "Error: run as root (use sudo), e.g.:"
  echo "  sudo bash $0"
  exit 1
fi

print_sep
print_center_equals "Running 0init.sh v01 (initinst + initusr)"
print_sep

echo ""
print_center_equals "[1/2] initinst.sh v01 - server-level setup"
bash "$SCRIPT_DIR/initinst.sh"

echo ""
print_center_equals "[2/2] initusr.sh v01 - user-level setup"
bash "$SCRIPT_DIR/initusr.sh" "$TARGET_USER"

echo ""
print_sep
echo "0init complete. Server-level and user-level setup finished."
echo "Safe to run again (idempotent where possible)."
print_sep
