#!/usr/bin/env bash
set -euo pipefail  # Exit on command errors, unset vars, and pipe failures.

# Purpose: enforce and verify effective SSH auth settings on target host.

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
Usage: sudo bash ssh_passwd_auth.sh

Enforces effective:
  PasswordAuthentication yes
  KbdInteractiveAuthentication yes
  UsePAM yes

USAGE
  exit 0
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

SSHD_MAIN_CONFIG="/etc/ssh/sshd_config"
SSHD_DROPIN_DIR="$(dirname "$SSHD_MAIN_CONFIG")/sshd_config.d"
OVERRIDE_FILE="$SSHD_DROPIN_DIR/zzzz-password-auth-override.conf"
TS="$(date +%Y%m%d_%H%M%S)"

if [[ ! -f "$SSHD_MAIN_CONFIG" ]]; then
  echo "Error: sshd_config not found: $SSHD_MAIN_CONFIG"
  exit 1
fi

mkdir -p "$SSHD_DROPIN_DIR"

cat > "$OVERRIDE_FILE" <<'CONF'
# Managed by ssh_passwd_auth.sh
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
CONF

echo "[1/3].a write_override v03 - Wrote override: $OVERRIDE_FILE"

if ! grep -Fq "# Managed by ssh_passwd_auth.sh (fallback)" "$SSHD_MAIN_CONFIG"; then
  cp -a "$SSHD_MAIN_CONFIG" "${SSHD_MAIN_CONFIG}.bak_${TS}"
  cat >> "$SSHD_MAIN_CONFIG" <<'CONF'

# Managed by ssh_passwd_auth.sh (fallback)
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
CONF
  echo "[1/3].a write_fallback v03 - Appended fallback block to: $SSHD_MAIN_CONFIG"
fi

echo "[2/3].b validate_sshd v03 - Validating sshd syntax..."
sshd -t -f "$SSHD_MAIN_CONFIG"

read_effective() {
  local out
  out="$(sshd -T -f "$SSHD_MAIN_CONFIG" -C user=root,host=localhost,addr=127.0.0.1)"
  effective_password="$(awk '/^passwordauthentication / {print $2}' <<< "$out")"
  effective_kbd="$(awk '/^kbdinteractiveauthentication / {print $2}' <<< "$out")"
  effective_pam="$(awk '/^usepam / {print $2}' <<< "$out")"
}

echo "[3/3].c verify_effective_settings v03 - Checking effective SSH settings..."
read_effective
echo "Effective PasswordAuthentication: ${effective_password:-<missing>}"
echo "Effective KbdInteractiveAuthentication: ${effective_kbd:-<missing>}"
echo "Effective UsePAM: ${effective_pam:-<missing>}"

if [[ "$effective_password" != "yes" || "$effective_kbd" != "yes" || "$effective_pam" != "yes" ]]; then
  echo "ERROR: Effective settings are not all 'yes'."
  echo "Inspect: /etc/ssh/sshd_config and /etc/ssh/sshd_config.d/*.conf"
  exit 1
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
  echo "Please restart manually on target host."
fi

echo "Done. SSH auth settings are effective (yes/yes/yes)."
