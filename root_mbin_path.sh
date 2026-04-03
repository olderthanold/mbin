#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures.

# Ensure root PATH includes /home/ubuntu/mbin, without duplicate config lines.
# Also ensure sudo secure_path includes mbin paths, so commands work with plain `sudo <cmd>`.

if [[ "$EUID" -ne 0 ]]; then  # Only root can safely edit /root/.bashrc.
  echo "Error: run as root (use sudo)."
  exit 1
fi

echo "Running root_mbin_path.sh v02"  # Simple run banner/version marker.

# File and text snippets used to make this script idempotent.
ROOT_BASHRC="/root/.bashrc"  # Target shell startup file for root user.
ROOT_PATH_MARKER="# Added by root_mbin_path.sh (ensure /home/ubuntu/mbin in root PATH)"
ROOT_PATH_LINE='export PATH="$PATH:/home/ubuntu/mbin"'  # PATH export to append.
SUDOERS_MBIN_PATH_FILE="/etc/sudoers.d/91-mbin-secure-path"
SUDO_SECURE_PATH='Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/root/mbin:/home/ubuntu/mbin"'

# 1) Root interactive shells: ensure /home/ubuntu/mbin is in /root/.bashrc.
if [[ ! -f "$ROOT_BASHRC" ]]; then
  touch "$ROOT_BASHRC"  # Create file if missing (minimal systems/containers).
fi

if ! grep -Fq "$ROOT_PATH_MARKER" "$ROOT_BASHRC"; then
  {  # Append marker + export line as one block for readability.
    echo ""
    echo "$ROOT_PATH_MARKER"
    echo "$ROOT_PATH_LINE"
  } >> "$ROOT_BASHRC"
  echo "Appended root PATH update to: $ROOT_BASHRC"
else
  echo "Root PATH marker already present in: $ROOT_BASHRC"  # No duplicate.
fi

# 2) sudo non-interactive/secure path: ensure mbin paths are available for `sudo <cmd>`.
if [[ -f "$SUDOERS_MBIN_PATH_FILE" ]] && grep -Fqx "$SUDO_SECURE_PATH" "$SUDOERS_MBIN_PATH_FILE"; then
  echo "Sudo secure_path mbin config already present: $SUDOERS_MBIN_PATH_FILE"
else
  echo "$SUDO_SECURE_PATH" > "$SUDOERS_MBIN_PATH_FILE"
  chmod 440 "$SUDOERS_MBIN_PATH_FILE"
  visudo -cf "$SUDOERS_MBIN_PATH_FILE" >/dev/null
  echo "Configured sudo secure_path in: $SUDOERS_MBIN_PATH_FILE"
fi

echo "Done. Root PATH support configured (idempotent)."
