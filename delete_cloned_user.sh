#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Reverts user account changes made by init_2_user_clone_user.sh for a cloned user:
# - removes /etc/sudoers.d/90-<user>-nopasswd when present (legacy cleanup only)
# - removes the user from system (and home/mail spool)
# - attempts to remove user private group when safe

usage() {
  cat <<'USAGE'
Usage:
  sudo bash delete_cloned_user.sh <cloned_user> [--force] [--dry-run]

Behavior:
  - Stops the target user's running processes
  - Removes /etc/sudoers.d/90-<user>-nopasswd if it exists (legacy cleanup)
  - Deletes the user account with home directory and mail spool
  - Tries to delete matching private group (if no members remain)

Notes:
  - This is intended to revert users created via init_2_user_clone_user.sh
  - Destructive operation: user home data is permanently removed
  - Does NOT require clone-marker file (init_2_user_clone_user.sh no longer creates one)
  - Refuses deletion if it would remove the last sudo-group member
    (important when direct root login is locked)
  - Use --force to override safety checks intentionally
  - Use --dry-run to print actions without changing anything
USAGE
}

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[dry-run] $*${NC}"
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
  echo -e "${RED}Error: run as root (use sudo).${NC}"
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

echo -e "${YELLOW}Running delete_cloned_user.sh v02${NC}"
echo "Target user: $TARGET_USER"
echo "Force mode: $FORCE"
echo "Dry-run mode: $DRY_RUN"

SUDOERS_FILE="/etc/sudoers.d/90-${TARGET_USER}-nopasswd"

if ! has_other_sudo_member && [[ "$FORCE" != "true" ]]; then
  echo "Refusing to proceed: deleting '$TARGET_USER' would leave no other sudo-group member."
  echo "This is blocked by default because root login may be locked."
  echo "Use --force only if you have confirmed alternate admin access (console/root key, etc.)."
  exit 1
fi

echo -e "${YELLOW}[1/4] stop_user_processes v01${NC}"
if [[ "$DRY_RUN" == "true" ]]; then
  echo -e "${YELLOW}[dry-run] pkill -u $TARGET_USER${NC}"
else
  pkill -u "$TARGET_USER" 2>/dev/null || true
fi

echo -e "${YELLOW}[2/4] remove_nopasswd_sudoers v01${NC}"
if [[ -f "$SUDOERS_FILE" ]]; then
  run_cmd rm -f "$SUDOERS_FILE"
  echo "Removed: $SUDOERS_FILE"
else
  echo "No sudoers override file found for user (skip)."
fi

echo -e "${YELLOW}[3/4] delete_user_account v01${NC}"
run_cmd userdel -r "$TARGET_USER"
echo "Deleted user and home/mail: $TARGET_USER"

echo -e "${YELLOW}[4/4] cleanup_private_group v01${NC}"
if getent group "$TARGET_USER" >/dev/null 2>&1; then
  if run_cmd groupdel "$TARGET_USER" 2>/dev/null; then
    echo "Removed private group: $TARGET_USER"
  else
    echo "Private group '$TARGET_USER' kept (still in use)."
  fi
else
  echo "No matching private group to remove."
fi

echo -e "${GREEN}Done. Revert complete for cloned user: $TARGET_USER${NC}"
