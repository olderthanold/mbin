#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures

# Ensures SSH daemon allows password + keyboard-interactive auth with PAM.
# Safe method used here:
#   - do NOT rewrite /etc/ssh/sshd_config directly
#   - create/update a dedicated override file in /etc/ssh/sshd_config.d/
#   - validate config with `sshd -t` before restart
#   - verify effective runtime values with `sshd -T`

usage() {
  cat <<'USAGE'
Usage: sudo bash ensure_ssh_password_auth.sh

This script enforces the following effective SSH settings:
  PasswordAuthentication yes
  KbdInteractiveAuthentication yes
  UsePAM yes

It writes an override file:
  /etc/ssh/sshd_config.d/zzzz-password-auth-override.conf

Then validates and restarts SSH safely.
USAGE
}

# Show help and exit without changes
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# This script modifies system SSH config and restarts service, so root is required
if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

# Main sshd config + drop-in override path
SSHD_MAIN_CONFIG="/etc/ssh/sshd_config"
SSHD_DROPIN_DIR="/etc/ssh/sshd_config.d"
OVERRIDE_FILE="$SSHD_DROPIN_DIR/zzzz-password-auth-override.conf"
MAIN_BACKUP_FILE="${SSHD_MAIN_CONFIG}.bak_$(date +%Y%m%d_%H%M%S)"

get_effective_settings() {
  # Provide -C context so Match blocks are evaluated for a realistic local login path.
  local values
  values="$(sshd -T -C user=root,host=localhost,addr=127.0.0.1)"
  effective_password="$(awk '/^passwordauthentication / {print $2}' <<< "$values")"
  effective_kbd="$(awk '/^kbdinteractiveauthentication / {print $2}' <<< "$values")"
  effective_pam="$(awk '/^usepam / {print $2}' <<< "$values")"
}

force_yes_in_file() {
  local file="$1"
  local tmp
  tmp="$(mktemp)"

  awk '
    {
      line = $0

      # Keep comments unchanged
      if (line ~ /^[[:space:]]*#/) {
        print line
        next
      }

      if (line ~ /^[[:space:]]*PasswordAuthentication[[:space:]]+/) {
        print "PasswordAuthentication yes"
        next
      }
      if (line ~ /^[[:space:]]*KbdInteractiveAuthentication[[:space:]]+/) {
        print "KbdInteractiveAuthentication yes"
        next
      }
      if (line ~ /^[[:space:]]*UsePAM[[:space:]]+/) {
        print "UsePAM yes"
        next
      }

      print line
    }
  ' "$file" > "$tmp"

  if ! cmp -s "$file" "$tmp"; then
    cp -a "$file" "${file}.bak_${TIMESTAMP}"
    install -m 644 "$tmp" "$file"
    echo "Adjusted existing directives to 'yes' in: $file"
  fi

  rm -f "$tmp"
}

# Guard: sshd main file must exist
if [[ ! -f "$SSHD_MAIN_CONFIG" ]]; then
  echo "Error: $SSHD_MAIN_CONFIG not found."
  exit 1
fi

# Ensure include dir exists
mkdir -p "$SSHD_DROPIN_DIR"

# Keep timestamped backup of previous override only when content changes
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${OVERRIDE_FILE}.bak_${TIMESTAMP}"

TMP_OVERRIDE_FILE="$(mktemp)"
trap 'rm -f "$TMP_OVERRIDE_FILE"' EXIT

cat > "$TMP_OVERRIDE_FILE" <<'CONF'
# Managed by ensure_ssh_password_auth.sh
# Keep this file lexicographically last so it wins over earlier values.
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
CONF

if [[ -f "$OVERRIDE_FILE" ]] && cmp -s "$TMP_OVERRIDE_FILE" "$OVERRIDE_FILE"; then
  echo "Override already up to date: $OVERRIDE_FILE"
else
  if [[ -f "$OVERRIDE_FILE" ]]; then
    cp -a "$OVERRIDE_FILE" "$BACKUP_FILE"  # Backup old override when changing
    echo "Backup created: $BACKUP_FILE"
  fi
  echo "Writing override file: $OVERRIDE_FILE"
  install -m 644 "$TMP_OVERRIDE_FILE" "$OVERRIDE_FILE"
fi

# Syntax validation before restart to avoid lockout from bad config
echo "Validating sshd configuration syntax..."
if ! sshd -t; then
  echo "ERROR: sshd -t failed. Restoring previous override file (if any)."
  if [[ -f "$BACKUP_FILE" ]]; then
    cp -a "$BACKUP_FILE" "$OVERRIDE_FILE"
    echo "Restored from backup: $BACKUP_FILE"
  else
    rm -f "$OVERRIDE_FILE"
    echo "Removed invalid override file."
  fi
  exit 1
fi

# Verify effective runtime values.
# This handles commented/overridden options correctly because sshd -T
# prints the final merged configuration.
echo "Checking effective SSH settings..."
get_effective_settings

echo "Effective PasswordAuthentication: ${effective_password:-<missing>}"
echo "Effective KbdInteractiveAuthentication: ${effective_kbd:-<missing>}"
echo "Effective UsePAM: ${effective_pam:-<missing>}"

if [[ "$effective_password" != "yes" || "$effective_kbd" != "yes" || "$effective_pam" != "yes" ]]; then
  echo "Drop-in was not enough; applying fallback at end of $SSHD_MAIN_CONFIG"
  if ! grep -Fq "# Managed by ensure_ssh_password_auth.sh (fallback)" "$SSHD_MAIN_CONFIG"; then
    cp -a "$SSHD_MAIN_CONFIG" "$MAIN_BACKUP_FILE"  # Backup main config only before first fallback append
    cat >> "$SSHD_MAIN_CONFIG" <<'CONF'

# Managed by ensure_ssh_password_auth.sh (fallback)
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
CONF
  else
    echo "Fallback block already present in $SSHD_MAIN_CONFIG"
  fi

  sshd -t  # Validate after fallback write
  get_effective_settings

  echo "Effective PasswordAuthentication (fallback): ${effective_password:-<missing>}"
  echo "Effective KbdInteractiveAuthentication (fallback): ${effective_kbd:-<missing>}"
  echo "Effective UsePAM (fallback): ${effective_pam:-<missing>}"

  if [[ "$effective_password" != "yes" || "$effective_kbd" != "yes" || "$effective_pam" != "yes" ]]; then
    echo "Fallback append was still not enough; normalizing existing directives in main + drop-ins..."

    force_yes_in_file "$SSHD_MAIN_CONFIG"
    while IFS= read -r -d '' f; do
      force_yes_in_file "$f"
    done < <(find "$SSHD_DROPIN_DIR" -maxdepth 1 -type f -name '*.conf' -print0)

    sshd -t
    get_effective_settings

    echo "Effective PasswordAuthentication (normalized): ${effective_password:-<missing>}"
    echo "Effective KbdInteractiveAuthentication (normalized): ${effective_kbd:-<missing>}"
    echo "Effective UsePAM (normalized): ${effective_pam:-<missing>}"

    if [[ "$effective_password" != "yes" || "$effective_kbd" != "yes" || "$effective_pam" != "yes" ]]; then
      echo "ERROR: Effective settings are still not all 'yes'."
      echo "Diagnostics (active directives):"
      grep -RIn --include='*.conf' --include='sshd_config' '^[[:space:]]*(PasswordAuthentication|KbdInteractiveAuthentication|UsePAM)[[:space:]]+' /etc/ssh || true
      exit 1
    fi
  fi
fi

# Restart SSH daemon.
# Ubuntu commonly uses ssh.service, while some distros use sshd.service.
echo "Restarting SSH service..."
if systemctl list-unit-files | grep -q '^ssh\.service'; then
  systemctl restart ssh  # Restart ssh service
  systemctl is-active --quiet ssh  # Confirm running
  echo "SSH service restarted successfully (ssh.service)."
elif systemctl list-unit-files | grep -q '^sshd\.service'; then
  systemctl restart sshd  # Restart sshd service
  systemctl is-active --quiet sshd  # Confirm running
  echo "SSH service restarted successfully (sshd.service)."
else
  echo "ERROR: Could not find ssh.service or sshd.service in systemd."
  exit 1
fi

echo
echo "Done: SSH password + keyboard-interactive auth with PAM are enabled."
echo "Safety note: Keep your current SSH session open while testing a new login."
echo "Test command (from another terminal):"
echo "  ssh <user>@<host>"
