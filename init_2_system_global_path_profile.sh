#!/usr/bin/env bash
set -euo pipefail

# init_2_system_global_path_profile.sh v04
#
# Purpose:
#   Configure one global PATH entry for all users via /etc/profile.d.
#
# Behavior:
#   - Ensures /opt/mbin exists
#   - Writes /etc/profile.d/mbin.sh for login shells
#   - Ensures /root/.bashrc has one effective non-commented PATH line for /opt/mbin
#   - Reuses existing passwordless-sudo drop-in location (from init_2_system_paaswordles_sudo.sh logic)
#     to ensure sudo secure_path includes /opt/mbin (no extra arbitrary sudoers file)

if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

echo "Running init_2_system_global_path_profile.sh v04"

MBIN_DIR="/opt/mbin"
PROFILE_FILE="/etc/profile.d/mbin.sh"
PROFILE_LINE='export PATH="/opt/mbin:$PATH"'
ROOT_BASHRC="/root/.bashrc"
ROOT_BASHRC_LINE='export PATH="/opt/mbin:$PATH"'
SUDOERS_LINE='Defaults secure_path="/opt/mbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"'
SUDOERS_DIR="/etc/sudoers.d"

has_passwordless_sudo_rule() {
  local file="$1"
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*%sudo[[:space:]]+ALL=\(ALL:ALL\)[[:space:]]+NOPASSWD:ALL[[:space:]]*$/ { found=1 }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

echo "[1/5] Ensuring global mbin directory exists: $MBIN_DIR"
mkdir -p "$MBIN_DIR"
chmod 755 "$MBIN_DIR"

echo "[2/5] Writing global PATH profile: $PROFILE_FILE"
printf '%s\n' "$PROFILE_LINE" > "$PROFILE_FILE"
chmod 644 "$PROFILE_FILE"

echo "[3/5] Normalizing root PATH line in $ROOT_BASHRC (non-commented matches only)"
touch "$ROOT_BASHRC"

mapfile -t root_matches < <(
  grep -nE '^[[:space:]]*export[[:space:]]+PATH=.*$' "$ROOT_BASHRC" | grep -F '/opt/mbin' || true
)

root_match_count="${#root_matches[@]}"
echo "Found $root_match_count non-commented PATH line(s) mentioning /opt/mbin in root bashrc."

if (( root_match_count == 0 )); then
  printf '\n%s\n' "$ROOT_BASHRC_LINE" >> "$ROOT_BASHRC"
  echo "No existing non-commented /opt/mbin PATH line found. Appended normalized line."
else
  last_line_no=0
  for match in "${root_matches[@]}"; do
    line_no="${match%%:*}"
    last_line_no="$line_no"
  done

  tmpfile="$(mktemp)"
  trap 'rm -f "$tmpfile"' EXIT

  awk -v last="$last_line_no" -v newline="$ROOT_BASHRC_LINE" '
    BEGIN {
      path_export_regex = "^[[:space:]]*export[[:space:]]+PATH=.*$"
    }
    NR == last {
      print newline
      next
    }
    ($0 ~ path_export_regex) && (index($0, "/opt/mbin") > 0) {
      next
    }
    {
      print
    }
  ' "$ROOT_BASHRC" > "$tmpfile"

  mv "$tmpfile" "$ROOT_BASHRC"
  trap - EXIT
  echo "Kept last non-commented match and normalized it; removed older /opt/mbin PATH matches."
fi

echo "[4/5] Ensuring sudo secure_path includes /opt/mbin (reusing existing passwordless-sudo file)"
mapfile -t sudoers_files < <(find "$SUDOERS_DIR" -maxdepth 1 -type f -printf "%f\n" | LC_ALL=C sort)

target_sudoers_file=""
for name in "${sudoers_files[@]}"; do
  file="$SUDOERS_DIR/$name"
  if has_passwordless_sudo_rule "$file"; then
    target_sudoers_file="$file"
  fi
done

if [[ -z "$target_sudoers_file" ]]; then
  echo "Error: no existing passwordless-sudo file found in $SUDOERS_DIR."
  echo "Run init_2_system_paaswordles_sudo.sh first, then re-run this script."
  exit 1
fi

if grep -Fqx "$SUDOERS_LINE" "$target_sudoers_file"; then
  echo "secure_path already present in: $target_sudoers_file"
else
  printf '%s\n' "$SUDOERS_LINE" >> "$target_sudoers_file"
  echo "Added secure_path to: $target_sudoers_file"
fi

chmod 440 "$target_sudoers_file"
visudo -cf "$target_sudoers_file" >/dev/null

echo "[5/5] Done. Global PATH for users/root/sudo is configured."
echo "New sessions will load: $PROFILE_LINE"
echo "Sudo secure_path file: $target_sudoers_file"
