#!/usr/bin/env bash
set -euo pipefail

# Ensure root PATH includes /home/ubuntu/mbin, without duplicate lines.
# Also ensure sudo secure_path includes mbin paths, so commands work with plain `sudo <cmd>`.

if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

echo "Running root_mbin_path.sh v03"

ROOT_BASHRC="/root/.bashrc"
ROOT_PATH_LINE='export PATH="$PATH:/home/ubuntu/mbin"'

SUDOERS_MBIN_PATH_FILE="/etc/sudoers.d/91-mbin-secure-path"
SUDO_SECURE_PATH='Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/root/mbin:/home/ubuntu/mbin"'

ensure_exact_line_in_file() {
  local file="$1"
  local line="$2"

  touch "$file"

  if grep -Fxq "$line" "$file"; then
    echo "Line already present in: $file"
  else
    printf '\n%s\n' "$line" >> "$file"
    echo "Appended line to: $file"
  fi
}

# 1) Root interactive shells: ensure /home/ubuntu/mbin is in /root/.bashrc.
ensure_exact_line_in_file "$ROOT_BASHRC" "$ROOT_PATH_LINE"

# 2) sudo secure path: validate first, then install atomically.
tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

printf '%s\n' "$SUDO_SECURE_PATH" > "$tmpfile"
chmod 440 "$tmpfile"
visudo -cf "$tmpfile" >/dev/null
mv "$tmpfile" "$SUDOERS_MBIN_PATH_FILE"
trap - EXIT

echo "Configured sudo secure_path in: $SUDOERS_MBIN_PATH_FILE"
echo "Done. Root PATH support configured."