#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Ensure sudo group has passwordless sudo rule:
#   %sudo ALL=(ALL:ALL) NOPASSWD:ALL
#
# Analogical logic to root_path_sudoers.sh:
# 1) List files in /etc/sudoers.d
# 2) Loop through all files and check whether they already contain the rule
# 3) If found in any file, exit with no changes
# 4) If found in none, check if there is an existing file ending with "mmm"
#    - if yes: append rule there (unless exact line already present)
#    - if no: create new file named <last_lexicographic_filename>mmm
#            and write rule there

if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo).${NC}"
  exit 1
fi

echo -e "${YELLOW}Running init_2_system_paaswordles_sudo.sh v01${NC}"

SUDOERS_DIR="/etc/sudoers.d"
RULE_LINE='%sudo ALL=(ALL:ALL) NOPASSWD:ALL'

if [[ ! -d "$SUDOERS_DIR" ]]; then
  echo -e "${RED}Error: sudoers include directory not found: $SUDOERS_DIR${NC}"
  exit 1
fi

# Returns success when file has non-commented exact sudo-group NOPASSWD rule.
has_passwordless_sudo_rule() {
  local file="$1"
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*%sudo[[:space:]]+ALL=\(ALL:ALL\)[[:space:]]+NOPASSWD:ALL[[:space:]]*$/ { found=1 }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

echo -e "${YELLOW}[1/5] Listing files in $SUDOERS_DIR ...${NC}"
mapfile -t sudoers_files < <(find "$SUDOERS_DIR" -maxdepth 1 -type f -printf "%f\n" | LC_ALL=C sort)

file_count="${#sudoers_files[@]}"
echo "Found $file_count file(s)."

if (( file_count == 0 )); then
  echo "No files found in $SUDOERS_DIR."
  base_name="99-sudo-nopasswd"
else
  base_name="${sudoers_files[file_count-1]}"
fi

echo -e "${YELLOW}[2/5] Looping through files and checking for passwordless sudo rule...${NC}"
found_any=0
last_mmm_file=""

for name in "${sudoers_files[@]}"; do
  file="$SUDOERS_DIR/$name"
  echo -e "${YELLOW}- Checking: $file${NC}"

  if [[ "$name" == *mmm ]]; then
    last_mmm_file="$file"  # Keep lexicographically last *mmm due to sorted input.
  fi

  if has_passwordless_sudo_rule "$file"; then
    echo "  Found passwordless sudo rule in: $file"
    found_any=1
  fi
done

if (( found_any == 1 )); then
  echo -e "${YELLOW}[3/5] Passwordless sudo rule already present. No changes needed.${NC}"
  echo -e "${YELLOW}[4/5] Skipping file creation/append.${NC}"
  echo -e "${YELLOW}[5/5] Done.${NC}"
  exit 0
fi

echo -e "${YELLOW}[3/5] Passwordless sudo rule not found in any file.${NC}"

if [[ -n "$last_mmm_file" ]]; then
  target_file="$last_mmm_file"
  if grep -Fqx "$RULE_LINE" "$target_file"; then
    echo "Found existing *mmm file with exact rule already present: $target_file"
    echo "Nothing to append."
  else
    echo "Found existing *mmm file. Appending rule to: $target_file"
    printf '%s\n' "$RULE_LINE" >> "$target_file"
  fi
else
  new_name="${base_name}mmm"
  target_file="$SUDOERS_DIR/$new_name"
  echo "No existing *mmm file. Creating new file: $target_file"
  printf '%s\n' "$RULE_LINE" > "$target_file"
fi

chmod 440 "$target_file"

echo -e "${YELLOW}[4/5] Validating sudoers drop-in with visudo...${NC}"
visudo -cf "$target_file" >/dev/null

echo -e "${YELLOW}[5/5] Done. Ensured passwordless sudo rule in: $target_file${NC}"
