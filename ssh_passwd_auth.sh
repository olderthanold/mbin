#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined vars, and failed pipelines.

# Simple SSH password-auth enablement for Ubuntu/Debian style sshd.

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then  # Help mode.
  cat <<'USAGE'
Usage: sudo bash ssh_passwd_auth.sh

Ensures these effective sshd settings are enabled:
  PasswordAuthentication yes
  KbdInteractiveAuthentication yes
  UsePAM yes
USAGE
  exit 0
fi

if [[ "$EUID" -ne 0 ]]; then  # We need root to edit /etc/ssh and restart sshd.
  echo "Error: run as root (use sudo)."
  exit 1
fi

SSHD_MAIN_CONFIG="/etc/ssh/sshd_config"  # Main OpenSSH daemon config file.
SSHD_DROPIN_DIR="/etc/ssh/sshd_config.d"  # Drop-in include directory.
OVERRIDE_FILE="$SSHD_DROPIN_DIR/zzzz-password-auth-override.conf"  # Last file.

mkdir -p "$SSHD_DROPIN_DIR"  # Ensure drop-in directory exists.

cat > "$OVERRIDE_FILE" <<'CONF'  # Rewrite file each run (idempotent).
# Managed by ssh_passwd_auth.sh
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
CONF

echo "Wrote override: $OVERRIDE_FILE"

echo "Validating sshd syntax..."
sshd -t  # Syntax check before reading effective config/restarting service.

read_effective() {
  local out  # Effective config snapshot for a concrete connection context.
  out="$(sshd -T -C user=root,host=localhost,addr=127.0.0.1)"
  effective_password="$(awk '/^passwordauthentication / {print $2}' <<< "$out")"
  effective_kbd="$(awk '/^kbdinteractiveauthentication / {print $2}' <<< "$out")"
  effective_pam="$(awk '/^usepam / {print $2}' <<< "$out")"
}

echo "Checking effective SSH settings..."
read_effective
echo "Effective PasswordAuthentication: ${effective_password:-<missing>}"
echo "Effective KbdInteractiveAuthentication: ${effective_kbd:-<missing>}"
echo "Effective UsePAM: ${effective_pam:-<missing>}"

# Straightforward fallback: add one final block in main config, then re-check.
if [[ "$effective_password" != "yes" || "$effective_kbd" != "yes" || "$effective_pam" != "yes" ]]; then
  echo "Drop-in did not win. Applying one managed fallback block in $SSHD_MAIN_CONFIG"
  if ! grep -Fq "# Managed by ssh_passwd_auth.sh (fallback)" "$SSHD_MAIN_CONFIG"; then
    cat >> "$SSHD_MAIN_CONFIG" <<'CONF'

# Managed by ssh_passwd_auth.sh (fallback)
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
CONF
  else
    echo "Fallback block already present; not appending duplicate."
  fi

  sshd -t  # Validate after fallback update.
  read_effective
  echo "Effective PasswordAuthentication (fallback): ${effective_password:-<missing>}"
  echo "Effective KbdInteractiveAuthentication (fallback): ${effective_kbd:-<missing>}"
  echo "Effective UsePAM (fallback): ${effective_pam:-<missing>}"

  if [[ "$effective_password" != "yes" || "$effective_kbd" != "yes" || "$effective_pam" != "yes" ]]; then
    echo "ERROR: Effective settings are still not all 'yes'."
    echo "Please check for restrictive Match blocks in /etc/ssh/sshd_config*"
    exit 1
  fi
fi

echo "Restarting SSH service..."  # Apply changes to running daemon.
if systemctl list-unit-files | grep -q '^ssh\.service'; then
  systemctl restart ssh  # Ubuntu/Debian service name.
  systemctl is-active --quiet ssh  # Fail if service did not come up.
elif systemctl list-unit-files | grep -q '^sshd\.service'; then
  systemctl restart sshd  # Alternate service name (some distros).
  systemctl is-active --quiet sshd  # Fail if service did not come up.
else
  echo "ERROR: Could not find ssh.service or sshd.service"
  exit 1
fi

echo "Done. SSH password + keyboard-interactive auth with PAM are enabled."
