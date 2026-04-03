#!/usr/bin/env bash
set -euo pipefail  # Exit on command errors, unset vars, and pipe failures.

# Test-copy variant of ssh_passwd_auth.sh.
# Supports running against an alternate sshd_config path for safe dry/local tests.

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
Usage: bash ssh_passwd_auth_test.sh [sshd_config_path]

Default target:
  /home/ubuntu/ssh/sshd_config

This script writes:
  <target_dir>/sshd_config.d/zzzz-password-auth-override.conf

And appends one managed fallback block into:
  <sshd_config_path>

When testing non-system config paths, restart is skipped.
USAGE
  exit 0
fi

SSHD_MAIN_CONFIG="${1:-/home/ubuntu/ssh/sshd_config}"
SSHD_DROPIN_DIR="$(dirname "$SSHD_MAIN_CONFIG")/sshd_config.d"
OVERRIDE_FILE="$SSHD_DROPIN_DIR/zzzz-password-auth-override.conf"
TS="$(date +%Y%m%d_%H%M%S)"

if [[ ! -f "$SSHD_MAIN_CONFIG" ]]; then
  echo "Error: sshd_config not found: $SSHD_MAIN_CONFIG"
  exit 1
fi

mkdir -p "$SSHD_DROPIN_DIR"

cat > "$OVERRIDE_FILE" <<'CONF'
# Managed by ssh_passwd_auth_test.sh
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
CONF

echo "[1/3].a write_override v01 - Wrote override: $OVERRIDE_FILE"

if ! grep -Fq "# Managed by ssh_passwd_auth_test.sh (fallback)" "$SSHD_MAIN_CONFIG"; then
  cp -a "$SSHD_MAIN_CONFIG" "${SSHD_MAIN_CONFIG}.bak_${TS}"
  cat >> "$SSHD_MAIN_CONFIG" <<'CONF'

# Managed by ssh_passwd_auth_test.sh (fallback)
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
CONF
  echo "[1/3].a write_fallback v01 - Appended fallback block to: $SSHD_MAIN_CONFIG"
fi

if ! command -v sshd >/dev/null 2>&1; then
  echo "[2/3].b validate_sshd v01 - Skipped (sshd binary not available in this shell)"
  echo "[3/3].c verify_effective_settings v01 - Skipped (no sshd -T support here)"
  echo "Done (test-write mode)."
  exit 0
fi

echo "[2/3].b validate_sshd v01 - Validating sshd syntax..."
sshd -t -f "$SSHD_MAIN_CONFIG"

out="$(sshd -T -f "$SSHD_MAIN_CONFIG" -C user=root,host=localhost,addr=127.0.0.1)"
effective_password="$(awk '/^passwordauthentication / {print $2}' <<< "$out")"
effective_kbd="$(awk '/^kbdinteractiveauthentication / {print $2}' <<< "$out")"
effective_pam="$(awk '/^usepam / {print $2}' <<< "$out")"

echo "[3/3].c verify_effective_settings v01 - Checking effective SSH settings..."
echo "Effective PasswordAuthentication: ${effective_password:-<missing>}"
echo "Effective KbdInteractiveAuthentication: ${effective_kbd:-<missing>}"
echo "Effective UsePAM: ${effective_pam:-<missing>}"

if [[ "$effective_password" != "yes" || "$effective_kbd" != "yes" || "$effective_pam" != "yes" ]]; then
  echo "ERROR: Effective settings are not all 'yes'."
  exit 1
fi

if [[ "$SSHD_MAIN_CONFIG" != "/etc/ssh/sshd_config" ]]; then
  echo "Custom target path used; skipping system SSH restart."
  echo "Done."
  exit 0
fi

echo "Applying settings (restart/reload SSH)..."
if systemctl restart ssh >/dev/null 2>&1; then
  echo "Restarted ssh service."
elif systemctl restart sshd >/dev/null 2>&1; then
  echo "Restarted sshd service."
elif systemctl restart ssh.socket >/dev/null 2>&1; then
  echo "Restarted ssh.socket (socket-activated sshd)."
else
  echo "WARNING: Could not restart ssh/sshd service automatically."
fi

echo "Done."
