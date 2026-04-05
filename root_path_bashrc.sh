#!/usr/bin/env bash
set -euo pipefail

# Ensure /root/.bashrc has one effective mbin PATH export line.
#
# Behavior:
# 1) grep all PATH export lines that mention the target mbin path
# 2) loop through and print all hits
# 3) remove all matching lines except the last hit
# 4) normalize the last hit to exactly:
#      export PATH="$PATH:<target_mbin_path>"
# 5) if no hit exists, append that line

if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

echo "Running root_path_bashrc.sh v01"

ROOT_BASHRC="/root/.bashrc"

# Optional argument: target mbin path.
# If omitted, default to current mbin path.
DEFAULT_MBIN_PATH="/home/ubuntu/mbin"
MBIN_PATH="${1:-$DEFAULT_MBIN_PATH}"

if [[ "$#" -gt 1 ]]; then
  echo "Usage: $0 [mbin_path]"
  echo "Example: $0 /home/ubuntu/mbin"
  exit 1
fi

ROOT_PATH_LINE="export PATH=\"\$PATH:${MBIN_PATH}\""
echo "Target mbin path: $MBIN_PATH"

echo "[1/4] Ensuring target file exists: $ROOT_BASHRC"
touch "$ROOT_BASHRC"

echo "[2/4] Reading all PATH lines mentioning $MBIN_PATH ..."
mapfile -t matches < <(
  grep -nE '^[[:space:]]*#?[[:space:]]*export[[:space:]]+PATH=.*$' "$ROOT_BASHRC" | grep -F "$MBIN_PATH" || true
)

match_count="${#matches[@]}"
echo "Found $match_count matching line(s)."

if (( match_count == 0 )); then
  echo "[3/4] No existing mbin PATH line found. Appending normalized line."
  printf '\n%s\n' "$ROOT_PATH_LINE" >> "$ROOT_BASHRC"
else
  echo "[3/4] Looping through all matched lines:"
  last_line_no=0
  idx=0
  for match in "${matches[@]}"; do
    idx=$((idx + 1))
    line_no="${match%%:*}"
    line_text="${match#*:}"
    echo "  - Match $idx at line $line_no: $line_text"
    last_line_no="$line_no"
  done

  echo "Removing all mbin PATH hits except the last one (line $last_line_no),"
  echo "and normalizing the last one to: $ROOT_PATH_LINE"

  tmpfile="$(mktemp)"
  trap 'rm -f "$tmpfile"' EXIT

  awk -v last="$last_line_no" -v newline="$ROOT_PATH_LINE" -v mbin_path="$MBIN_PATH" '
    BEGIN {
      path_export_regex = "^[[:space:]]*#?[[:space:]]*export[[:space:]]+PATH=.*$"
    }
    NR == last {
      print newline
      next
    }
    ($0 ~ path_export_regex) && (index($0, mbin_path) > 0) {
      next
    }
    {
      print
    }
  ' "$ROOT_BASHRC" > "$tmpfile"

  mv "$tmpfile" "$ROOT_BASHRC"
  trap - EXIT
fi

echo "[4/4] Done. Root PATH mbin line cleaned and normalized in: $ROOT_BASHRC"
