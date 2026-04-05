#!/usr/bin/env bash
set -euo pipefail

# Ensure sudo secure_path contains a target path.
#
# Logic:
# 1) List files in /etc/sudoers.d
# 2) Loop through all files and check whether they contain target text
#    (default target text/path: "/home/ubuntu/mbin", unless argument supplied)
# 3) If found in any file, exit with no changes
# 4) If found in none, create a new file based on the lexicographically last
#    existing sudoers.d filename + "mmm", and write secure_path line there

if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

echo "Running root_path_sudoers.sh v01"

SUDOERS_DIR="/etc/sudoers.d"
TARGET_PATH="${1:-/home/ubuntu/mbin}"

if [[ "$#" -gt 1 ]]; then
  echo "Usage: $0 [path_to_ensure]"
  echo "Example: $0 /home/ubuntu/mbin"
  exit 1
fi

if [[ ! -d "$SUDOERS_DIR" ]]; then
  echo "Error: sudoers include directory not found: $SUDOERS_DIR"
  exit 1
fi

echo "Target path/text to check: $TARGET_PATH"
echo "[1/5] Listing files in $SUDOERS_DIR ..."

mapfile -t sudoers_files < <(find "$SUDOERS_DIR" -maxdepth 1 -type f -printf "%f\n" | LC_ALL=C sort)

file_count="${#sudoers_files[@]}"
echo "Found $file_count file(s)."

if (( file_count == 0 )); then
  echo "No files found in $SUDOERS_DIR."
  base_name="99-mbin-secure-path"
else
  base_name="${sudoers_files[file_count-1]}"
fi

echo "[2/5] Looping through files and checking for target text..."
found_any=0

for name in "${sudoers_files[@]}"; do
  file="$SUDOERS_DIR/$name"
  echo "- Checking: $file"

  if grep -Fq "$TARGET_PATH" "$file"; then
    echo "  Found target text in: $file"
    found_any=1
  fi
done

if (( found_any == 1 )); then
  echo "[3/5] Target already present in sudoers.d. No changes needed."
  echo "[4/5] Skipping file creation."
  echo "[5/5] Done."
  exit 0
fi

new_name="${base_name}mmm"
new_file="$SUDOERS_DIR/$new_name"

echo "[3/5] Target not found in any file."
echo "Creating new file: $new_file"

# Use a stable secure_path baseline and append target path.
secure_line="Defaults secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:${TARGET_PATH}\""

printf '%s\n' "$secure_line" > "$new_file"
chmod 440 "$new_file"

echo "[4/5] Validating new sudoers drop-in with visudo..."
visudo -cf "$new_file" >/dev/null

echo "[5/5] Done. Added secure_path entry in: $new_file"
