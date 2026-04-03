#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures

# Reverts user account changes made by clone_user.sh for a cloned user:
# - removes /etc/sudoers.d/90-<user>-nopasswd when present
# - removes the user from system (and home/mail spool)
# - attempts to remove user private group when safe

usage() {
  cat <<'USAGE'
Usage:
  sudo bash delete_cloned_user.sh <cloned_user> [--force] [--dry-run]

Behavior:
  - Stops the target user's running processes
  - Removes /etc/sudoers.d/90-<user>-nopasswd if it exists
  - Deletes the user account with home directory and mail spool
  - Tries to delete matching private group (if no members remain)

Notes:
  - This is intended to revert users created via clone_user.sh
  - Destructive operation: user home data is permanently removed
  - By default, refuses deletion if clone marker sudoers file is missing
  - Use --force to override safety checks intentionally
  - Use --dry-run to print actions without changing anything
USAGE
}

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

has_other_sudo_member() {
  local members
  members="$(getent group sudo | awk -F: '{print $4}')"
  # True when at least one sudo-group member exists that is not target and not empty
  awk -v target="$TARGET_USER" -F, '
    {
      for (i=1; i<=NF; i++) {
        gsub(/^ +| +$/, "", $i)
        if ($i != "" && $i != target) { found=1 }
      }
    }
    END { exit(found ? 0 : 1) }
  ' <<< "$members"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "Error: run as root (use sudo)."
  exit 1
fi

TARGET_USER="${1:-}"
if [[ -z "$TARGET_USER" ]]; then
  usage
  exit 1
fi

FORCE="false"
DRY_RUN="false"
for arg in "${@:2}"; do
  case "$arg" in
    --force) FORCE="true" ;;
    --dry-run) DRY_RUN="true" ;;
    *)
      echo "Unknown option: $arg"
      usage
      exit 1
      ;;
  esac
done

# Safety guards
if [[ "$TARGET_USER" == "root" ]]; then
  echo "Refusing to delete root user."
  exit 1
fi

if [[ "$TARGET_USER" == "${SUDO_USER:-}" ]]; then
  echo "Refusing to delete the sudo-invoking user: $TARGET_USER"
  exit 1
fi

case "$TARGET_USER" in
  ubuntu|opc|ec2-user|debian|oracle|admin)
    if [[ "$FORCE" != "true" ]]; then
      echo "Refusing to delete potentially primary access user '$TARGET_USER' without --force"
      exit 1
    fi
    ;;
esac

if [[ "$TARGET_USER" =~ [[:space:]:/] ]]; then
  echo "Invalid username: '$TARGET_USER'"
  exit 1
fi

if ! getent passwd "$TARGET_USER" >/dev/null 2>&1; then
  echo "User '$TARGET_USER' does not exist. Nothing to delete."
  exit 0
fi

echo "Running delete_cloned_user.sh v01"
echo "Target user: $TARGET_USER"
echo "Force mode: $FORCE"
echo "Dry-run mode: $DRY_RUN"

SUDOERS_FILE="/etc/sudoers.d/90-${TARGET_USER}-nopasswd"

if [[ ! -f "$SUDOERS_FILE" && "$FORCE" != "true" ]]; then
  echo "Refusing to proceed: clone marker missing ($SUDOERS_FILE)."
  echo "Use --force only if you intentionally want to delete a non-clone/partially configured user."
  exit 1
fi

if [[ -f "$SUDOERS_FILE" ]]; then
  expected_line="$TARGET_USER ALL=(ALL) NOPASSWD:ALL"
  if ! grep -Fqx "$expected_line" "$SUDOERS_FILE" && [[ "$FORCE" != "true" ]]; then
    echo "Refusing to remove unexpected sudoers file content in: $SUDOERS_FILE"
    echo "Use --force to override."
    exit 1
  fi
fi

if ! has_other_sudo_member && [[ "$FORCE" != "true" ]]; then
  echo "Refusing to proceed: no other sudo-group member detected besides target user."
  echo "Use --force only if you are certain alternate admin access exists (console/root key, etc.)."
  exit 1
fi

echo "[1/4] stop_user_processes v01"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[dry-run] pkill -u $TARGET_USER"
else
  pkill -u "$TARGET_USER" 2>/dev/null || true
fi

echo "[2/4] remove_nopasswd_sudoers v01"
if [[ -f "$SUDOERS_FILE" ]]; then
  run_cmd rm -f "$SUDOERS_FILE"
  echo "Removed: $SUDOERS_FILE"
else
  echo "No sudoers override file found for user (skip)."
fi

echo "[3/4] delete_user_account v01"
run_cmd userdel -r "$TARGET_USER"
echo "Deleted user and home/mail: $TARGET_USER"

echo "[4/4] cleanup_private_group v01"
if getent group "$TARGET_USER" >/dev/null 2>&1; then
  if run_cmd groupdel "$TARGET_USER" 2>/dev/null; then
    echo "Removed private group: $TARGET_USER"
  else
    echo "Private group '$TARGET_USER' kept (still in use)."
  fi
else
  echo "No matching private group to remove."
fi

echo "Done. Revert complete for cloned user: $TARGET_USER"
