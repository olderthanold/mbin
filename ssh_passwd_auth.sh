#!/usr/bin/env bash
set -euo pipefail

# Enforce one effective directive (set to "yes") for each option below
# in both target SSH config files.

SSHD_BIN="/usr/sbin/sshd"

# Settings of interest (processed in this order).
DIRECTIVES=(
  "PasswordAuthentication"
  "KbdInteractiveAuthentication"
  "UsePAM"
)

# Target files requested by user.
TARGET_FILES=(
  "/etc/ssh/sshd_config"
  "/etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
)

echo "Running ssh_passwd_auth.sh v02"

# Optional flag: --force
# - default (no flag): if initial compliance check passes, exit with no changes.
# - --force: run enforcement even if already compliant.
FORCE=0
if [[ "${1:-}" == "--force" ]]; then
  FORCE=1
  shift
fi

if [[ "$#" -ne 0 ]]; then
  echo "Usage: $0 [--force]"
  exit 1
fi

# Check helper: list all existing NON-commented directive hits + values.
# This is used once at the beginning and once at the end.
report_nonhashed_hits() {
  local label="$1"

  echo ""
  echo "=================================================="
  echo "[$label] Non-commented hits for all settings of interest"

  for target_file in "${TARGET_FILES[@]}"; do
    echo ""
    echo "File: $target_file"

    if [[ ! -f "$target_file" ]]; then
      echo "  (file does not exist, skipped)"
      continue
    fi

    for directive in "${DIRECTIVES[@]}"; do
      mapfile -t hits < <(
        grep -nE "^[[:space:]]*${directive}[[:space:]]+[^[:space:]#]+" "$target_file" || true
      )

      if (( ${#hits[@]} == 0 )); then
        echo "  $directive: <none>"
        continue
      fi

      for hit in "${hits[@]}"; do
        local line_no="${hit%%:*}"
        local line_text="${hit#*:}"
        local value
        value="$(awk '{print $2}' <<< "$line_text")"
        echo "  $directive @ line $line_no => $value"
      done
    done
  done
}

# Return 0 when a single directive line exists and is already set to yes.
# Return 1 otherwise.
directive_is_compliant_in_file() {
  local target_file="$1"
  local directive="$2"

  mapfile -t matches < <(
    grep -nE "^[[:space:]]*#?[[:space:]]*${directive}([[:space:]]+.*)?$" "$target_file" || true
  )

  if (( ${#matches[@]} != 1 )); then
    return 1
  fi

  local line_text="${matches[0]#*:}"

  if [[ "$line_text" =~ ^[[:space:]]*${directive}[[:space:]]+yes([[:space:]]*(#.*)?)?$ ]]; then
    return 0
  fi

  return 1
}

# Return 0 if entire file is compliant for all directives, else 1.
file_is_compliant() {
  local target_file="$1"

  if [[ ! -f "$target_file" ]]; then
    return 1
  fi

  local directive
  for directive in "${DIRECTIVES[@]}"; do
    if ! directive_is_compliant_in_file "$target_file" "$directive"; then
      return 1
    fi
  done

  return 0
}

# Procedure: enforce directive rules against one target file.
enforce_ssh_auth_directives() {
  local target_file="$1"

  if [[ ! -f "$target_file" ]]; then
    echo "Error: target file not found: $target_file"
    return 1
  fi

  if [[ ! -w "$target_file" ]]; then
    echo "Error: target file is not writable: $target_file"
    echo "Hint: run with sudo if this is a system config file."
    return 1
  fi

  # Skip edit/backup if nothing needs to change (unless --force is used).
  if (( FORCE == 0 )) && file_is_compliant "$target_file"; then
    echo "No changes needed for: $target_file"
    return 0
  fi

  local backup_file
  backup_file="${target_file}.bak_$(date +%Y%m%d_%H%M%S)"
  echo "[1/5] Creating backup: $backup_file"
  cp "$target_file" "$backup_file"

  echo "[2/5] Processing directives in sequence..."
  for directive in "${DIRECTIVES[@]}"; do
    echo ""
    echo "--- Processing: $directive ---"
    echo "Reading all '$directive' lines from $target_file using grep..."

    mapfile -t matches < <(
      grep -nE "^[[:space:]]*#?[[:space:]]*${directive}([[:space:]]+.*)?$" "$target_file" || true
    )

    local match_count
    match_count="${#matches[@]}"
    echo "Found $match_count matching line(s)."

    if (( match_count == 0 )); then
      echo "No existing '$directive' lines found. Appending '${directive} yes'."
      printf '\n%s\n' "${directive} yes" >> "$target_file"
      continue
    fi

    echo "Looping through all matched lines:"
    local last_line_no=0
    local idx=0
    local line_no
    local line_text
    local match

    for match in "${matches[@]}"; do
      idx=$((idx + 1))
      line_no="${match%%:*}"
      line_text="${match#*:}"
      echo "  - Match $idx at line $line_no: $line_text"
      last_line_no="$line_no"
    done

    echo "Removing all '$directive' lines except the last one (line $last_line_no),"
    echo "and forcing the last one to '${directive} yes'."

    local tmp_file
    tmp_file="$(mktemp)"
    trap 'rm -f "$tmp_file"' EXIT

    awk -v last="$last_line_no" -v directive="$directive" '
      BEGIN {
        regex = "^[[:space:]]*#?[[:space:]]*" directive "([[:space:]]+.*)?$"
      }
      NR == last {
        print directive " yes"
        next
      }
      $0 ~ regex {
        next
      }
      {
        print
      }
    ' "$target_file" > "$tmp_file"

    mv "$tmp_file" "$target_file"
    trap - EXIT
  done

  echo ""
  echo "[3/5] Validating sshd config syntax with: $SSHD_BIN -t -f $target_file"
  if [[ -x "$SSHD_BIN" ]]; then
    # On some systems /run/sshd may not exist until ssh service initialization.
    # Ensure directory exists so validation does not fail with:
    #   "Missing privilege separation directory: /run/sshd"
    if [[ ! -d "/run/sshd" ]]; then
      echo "Creating missing privilege separation directory: /run/sshd"
      mkdir -p /run/sshd
      chmod 755 /run/sshd
    fi
    "$SSHD_BIN" -t -f "$target_file"
  else
    echo "Warning: $SSHD_BIN not found/executable, skipping validation step."
  fi

  echo "[4/5] Done. All required directives now resolve to 'yes' in $target_file."
  echo "[5/5] Finished successfully."
  echo "Backup kept at: $backup_file"
}

# Check 1/2: state before changes.
report_nonhashed_hits "CHECK 1/2 - BEFORE"

# If all target files already comply, exit early (unless --force is used).
all_compliant=1
for target_file in "${TARGET_FILES[@]}"; do
  if ! file_is_compliant "$target_file"; then
    all_compliant=0
    break
  fi
done

if (( FORCE == 0 && all_compliant == 1 )); then
  echo ""
  echo "Initial check passed. No changes are needed."
  exit 0
fi

if (( FORCE == 1 )); then
  echo ""
  echo "--force enabled: running enforcement even if already compliant."
fi

echo ""
echo "Running directive enforcement for required files..."
for target_file in "${TARGET_FILES[@]}"; do
  echo ""
  echo "=================================================="
  echo "Target file: $target_file"

  # If the drop-in file does not exist yet, create it so the procedure can run.
  if [[ ! -f "$target_file" ]]; then
    echo "File does not exist; creating it: $target_file"
    touch "$target_file"
  fi

  enforce_ssh_auth_directives "$target_file"
done

echo ""
echo "All requested files processed successfully."

# Check 2/2: state after changes.
report_nonhashed_hits "CHECK 2/2 - AFTER"
