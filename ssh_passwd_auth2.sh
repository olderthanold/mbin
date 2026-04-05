#!/usr/bin/env bash
set -euo pipefail

SSHD_BIN="/usr/sbin/sshd"
MAIN="/etc/ssh/sshd_config"
DROPIN_DIR="/etc/ssh/sshd_config.d"
CLOUD_FILE="$DROPIN_DIR/60-cloudimg-settings.conf"

need_fix=0

read_effective() {
  local out
  out="$("$SSHD_BIN" -T -C user=root,host=localhost,addr=127.0.0.1)"
  pw="$(awk '/^passwordauthentication / {print $2}' <<< "$out")"
  kbd="$(awk '/^kbdinteractiveauthentication / {print $2}' <<< "$out")"
  pam="$(awk '/^usepam / {print $2}' <<< "$out")"
}

echo "[1] Checking effective SSH settings..."
read_effective
echo "PasswordAuthentication: $pw"
echo "KbdInteractiveAuthentication: $kbd"
echo "UsePAM: $pam"

if [[ "$pw" != "yes" || "$kbd" != "yes" || "$pam" != "yes" ]]; then
  need_fix=1
fi

if [[ "$need_fix" -eq 0 ]]; then
  echo "[OK] Already correct"
  exit 0
fi

echo "[2] Fixing..."

# Ensure drop-in dir exists
mkdir -p "$DROPIN_DIR"

# Fix cloud override if present (most common culprit)
if [[ -f "$CLOUD_FILE" ]]; then
  echo "Fixing $CLOUD_FILE"
  sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$CLOUD_FILE"
else
  # fallback: create early override file
  FIX_FILE="$DROPIN_DIR/00-password-auth.conf"
  echo "Creating $FIX_FILE"
  cat > "$FIX_FILE" <<EOF
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
EOF
fi

# Validate config
echo "[3] Validating sshd config..."
"$SSHD_BIN" -t -f "$MAIN"

# Reload SSH
echo "[4] Reloading ssh..."
systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true

# Re-check
echo "[5] Verifying..."
read_effective
echo "PasswordAuthentication: $pw"
echo "KbdInteractiveAuthentication: $kbd"
echo "UsePAM: $pam"

if [[ "$pw" == "yes" && "$kbd" == "yes" && "$pam" == "yes" ]]; then
  echo "[OK] Fixed"
else
  echo "[ERROR] Still not correct"
  exit 1
fi