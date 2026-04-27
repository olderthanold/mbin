#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ini2sys_global_path_profile.sh v06
#
# Purpose:
#   Configure one global PATH entry for all users via /etc/profile.d.
#
# Behavior:
#   - Ensures /m/mbin exists
#   - Writes /etc/profile.d/mbin.sh for login shells
#   - Ensures /root/.bashrc has one effective non-commented PATH line for /m/mbin
#   - Reuses existing passwordless-sudo drop-in location (from ini2sys_paaswordles_sudo.sh logic)
#     to ensure sudo secure_path includes /m/mbin (no extra arbitrary sudoers file)

if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo).${NC}"
  exit 1
fi

echo -e "${YELLOW}Running ini2sys_global_path_profile.sh v06${NC}"

MBIN_NAME="mbin"
MBIN_DIR="/m/$MBIN_NAME"
OLD_MBIN_DIR="/opt/$MBIN_NAME"
PROFILE_FILE="/etc/profile.d/mbin.sh"
PROFILE_LINE="export PATH=\"${MBIN_DIR}:\$PATH\""
ROOT_BASHRC="/root/.bashrc"
ROOT_BASHRC_LINE="$PROFILE_LINE"
SUDOERS_LINE="Defaults secure_path=\"${MBIN_DIR}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin\""
SUDOERS_DIR="/etc/sudoers.d"

has_passwordless_sudo_rule() {
  local file="$1"
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*%sudo[[:space:]]+ALL=\(ALL:ALL\)[[:space:]]+NOPASSWD:ALL[[:space:]]*$/ { found=1 }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

echo -e "${YELLOW}[1/5] Ensuring global mbin directory exists: $MBIN_DIR${NC}"
mkdir -p "$MBIN_DIR"
chmod 755 "$MBIN_DIR"

echo -e "${YELLOW}[2/5] Writing global PATH profile: $PROFILE_FILE${NC}"
printf '%s\n' "$PROFILE_LINE" > "$PROFILE_FILE"
chmod 644 "$PROFILE_FILE"

echo -e "${YELLOW}[3/5] Normalizing root PATH line in $ROOT_BASHRC (non-commented matches only)${NC}"
touch "$ROOT_BASHRC"

mapfile -t root_matches < <(
  grep -nE '^[[:space:]]*export[[:space:]]+PATH=.*$' "$ROOT_BASHRC" | grep -F -e "$OLD_MBIN_DIR" -e "$MBIN_DIR" || true
)

root_match_count="${#root_matches[@]}"
echo "Found $root_match_count non-commented PATH line(s) mentioning mbin paths in root bashrc."

if (( root_match_count == 0 )); then
  printf '\n%s\n' "$ROOT_BASHRC_LINE" >> "$ROOT_BASHRC"
  echo "No existing non-commented mbin PATH line found. Appended normalized line."
else
  last_line_no=0
  for match in "${root_matches[@]}"; do
    line_no="${match%%:*}"
    last_line_no="$line_no"
  done

  tmpfile="$(mktemp)"
  trap 'rm -f "$tmpfile"' EXIT

  awk -v last="$last_line_no" -v newline="$ROOT_BASHRC_LINE" -v old_dir="$OLD_MBIN_DIR" -v mbin_dir="$MBIN_DIR" '
    BEGIN {
      path_export_regex = "^[[:space:]]*export[[:space:]]+PATH=.*$"
    }
    NR == last {
      print newline
      next
    }
    ($0 ~ path_export_regex) && ((index($0, old_dir) > 0) || (index($0, mbin_dir) > 0)) {
      next
    }
    {
      print
    }
  ' "$ROOT_BASHRC" > "$tmpfile"

  mv "$tmpfile" "$ROOT_BASHRC"
  trap - EXIT
  echo "Kept last non-commented match and normalized it; removed older mbin PATH matches."
fi

echo -e "${YELLOW}[4/5] Ensuring sudo secure_path includes $MBIN_DIR (reusing existing passwordless-sudo file)${NC}"
mapfile -t sudoers_files < <(find "$SUDOERS_DIR" -maxdepth 1 -type f -printf "%f\n" | LC_ALL=C sort)

target_sudoers_file=""
for name in "${sudoers_files[@]}"; do
  file="$SUDOERS_DIR/$name"
  if has_passwordless_sudo_rule "$file"; then
    target_sudoers_file="$file"
  fi
done

if [[ -z "$target_sudoers_file" ]]; then
  echo -e "${RED}Error: no existing passwordless-sudo file found in $SUDOERS_DIR.${NC}"
  echo "Run ini2sys_paaswordles_sudo.sh first, then re-run this script."
  exit 1
fi

tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

awk -v old_dir="$OLD_MBIN_DIR" -v mbin_dir="$MBIN_DIR" '
  /^[[:space:]]*#/ { print; next }
  /^[[:space:]]*Defaults[[:space:]]+secure_path=/ && ((index($0, old_dir) > 0) || (index($0, mbin_dir) > 0)) {
    next
  }
  { print }
' "$target_sudoers_file" > "$tmpfile"

printf '%s\n' "$SUDOERS_LINE" >> "$tmpfile"
mv "$tmpfile" "$target_sudoers_file"
trap - EXIT
echo "Normalized secure_path in: $target_sudoers_file"

chmod 440 "$target_sudoers_file"
visudo -cf "$target_sudoers_file" >/dev/null

echo -e "${YELLOW}[5/5] Done. Global PATH for users/root/sudo is configured.${NC}"
echo "New sessions will load: $PROFILE_LINE"
echo "Sudo secure_path file: $target_sudoers_file"
