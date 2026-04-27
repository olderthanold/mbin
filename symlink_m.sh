#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# symlink_m.sh v02
#
# Purpose:
#   Create /m runtime layout and compatibility symlinks for older paths.
#
# Defaults:
#   /m/mbin      <- legacy /opt/mbin and /home/<user>/mbin
#   /m/webs      <- legacy /webs
#   /m/llama.cpp <- legacy /home/<user>/ai/llama.cpp
#
# Notes:
#   - Private SSH keys stay in ~/.ssh; this script does not move or link them.
#   - Existing real legacy paths are not overwritten unless --force is used.
#   - With --force, existing non-symlink legacy paths are moved to a timestamped
#     backup next to the original path before creating the symlink.
#   - The legacy user is added to www-data so /m/webs can be maintained
#     directly after this script runs.

FORCE="false"
DRY_RUN="false"
LEGACY_USER="${LEGACY_USER:-ubun2}"

show_help() {
  cat <<'USAGE'
Usage:
  sudo bash symlink_m.sh [--force] [--dry-run] [--user <name>]

Options:
  --force       Move existing non-symlink legacy paths to *.bak_<timestamp>
                before creating symlinks.
  --dry-run     Print actions without changing anything.
  --user <name> User whose home legacy links should be managed.
                Default: ubun2
  -h, --help    Show help.

Environment overrides:
  M_BASE_DIR    Default: /m
  MBIN_DIR      Default: /m/mbin
  WEB_BASE_DIR  Default: /m/webs
  LLAMA_DIR     Default: /m/llama.cpp
  LEGACY_USER   Default: ubun2
USAGE
}

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[dry-run] $*${NC}"
  else
    "$@"
  fi
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --user)
      if [[ "$#" -lt 2 || "$2" == -* ]]; then
        echo -e "${RED}Error: --user requires a value.${NC}"
        show_help
        exit 1
      fi
      LEGACY_USER="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Error: unknown option '$1'.${NC}"
      show_help
      exit 1
      ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo).${NC}"
  exit 1
fi

M_BASE_DIR="${M_BASE_DIR:-/m}"
MBIN_DIR="${MBIN_DIR:-${M_BASE_DIR}/mbin}"
WEB_BASE_DIR="${WEB_BASE_DIR:-${M_BASE_DIR}/webs}"
LLAMA_DIR="${LLAMA_DIR:-${M_BASE_DIR}/llama.cpp}"
WEB_GROUP="${WEB_GROUP:-www-data}"
BACKUP_SUFFIX="bak_$(date +%Y%m%d_%H%M%S)"

resolve_legacy_home() {
  local user="$1"
  local passwd_entry

  passwd_entry="$(getent passwd "$user" 2>/dev/null || true)"
  if [[ -n "$passwd_entry" ]]; then
    cut -d: -f6 <<< "$passwd_entry"
    return 0
  fi

  echo "/home/$user"
}

ensure_dir() {
  local path="$1"
  local mode="${2:-755}"

  if [[ -d "$path" ]]; then
    echo "Directory exists: $path"
  else
    echo "Creating directory: $path"
    run_cmd mkdir -p "$path"
  fi

  echo "Setting mode $mode on: $path"
  run_cmd chmod "$mode" "$path"
}

ensure_link() {
  local legacy_path="$1"
  local target_path="$2"
  local parent_dir
  local current_target
  local backup_path

  parent_dir="$(dirname "$legacy_path")"

  if [[ ! -d "$target_path" ]]; then
    echo "Creating symlink target directory: $target_path"
    run_cmd mkdir -p "$target_path"
  fi

  if [[ ! -d "$parent_dir" ]]; then
    echo "Creating legacy parent directory: $parent_dir"
    run_cmd mkdir -p "$parent_dir"
  fi

  if [[ -L "$legacy_path" ]]; then
    current_target="$(readlink "$legacy_path")"
    if [[ "$current_target" == "$target_path" ]]; then
      echo -e "${GREEN}OK symlink already exists: $legacy_path -> $target_path${NC}"
      return 0
    fi

    if [[ "$FORCE" != "true" ]]; then
      echo -e "${YELLOW}Skip: symlink exists with different target: $legacy_path -> $current_target${NC}"
      echo "      Re-run with --force to replace it."
      return 0
    fi

    echo "Replacing symlink: $legacy_path -> $current_target"
    run_cmd rm -f "$legacy_path"
  elif [[ -e "$legacy_path" ]]; then
    if [[ "$FORCE" != "true" ]]; then
      echo -e "${YELLOW}Skip: legacy path exists and is not a symlink: $legacy_path${NC}"
      echo "      Re-run with --force to move it aside and create the symlink."
      return 0
    fi

    backup_path="${legacy_path}.${BACKUP_SUFFIX}"
    echo "Moving existing legacy path aside: $legacy_path -> $backup_path"
    run_cmd mv "$legacy_path" "$backup_path"
  fi

  echo "Creating symlink: $legacy_path -> $target_path"
  run_cmd ln -s "$target_path" "$legacy_path"
}

LEGACY_HOME="$(resolve_legacy_home "$LEGACY_USER")"
LEGACY_GROUP=""
if id "$LEGACY_USER" >/dev/null 2>&1; then
  LEGACY_GROUP="$(id -gn "$LEGACY_USER")"
fi

ensure_owner() {
  local path="$1"
  local owner="$2"
  local group="$3"

  if [[ -z "$owner" || -z "$group" ]]; then
    return 0
  fi

  if [[ -e "$path" ]]; then
    echo "Setting owner/group on: $path -> $owner:$group"
    run_cmd chown "$owner:$group" "$path"
  fi
}

ensure_group() {
  local group="$1"

  if getent group "$group" >/dev/null 2>&1; then
    echo "Group exists: $group"
  else
    echo "Creating system group: $group"
    run_cmd groupadd --system "$group"
  fi
}

ensure_user_in_group() {
  local user="$1"
  local group="$2"

  if [[ -z "$user" || "$user" == "root" ]]; then
    echo "Skipping group membership for user: ${user:-<empty>}"
    return 0
  fi

  if ! id "$user" >/dev/null 2>&1; then
    echo -e "${YELLOW}Skip group membership: user not found: $user${NC}"
    return 0
  fi

  if id -nG "$user" | tr ' ' '\n' | grep -Fxq "$group"; then
    echo "User '$user' is already in group '$group'."
  else
    echo "Adding user '$user' to group '$group'."
    run_cmd usermod -aG "$group" "$user"
    echo "Note: a new login session may be required before group membership is visible to that user."
  fi
}

echo -e "${YELLOW}Running symlink_m.sh v02${NC}"
echo "Force mode: $FORCE"
echo "Dry-run mode: $DRY_RUN"
echo "M base: $M_BASE_DIR"
echo "mbin target: $MBIN_DIR"
echo "web target: $WEB_BASE_DIR"
echo "llama target: $LLAMA_DIR"
echo "web group: $WEB_GROUP"
echo "legacy user: $LEGACY_USER"
echo "legacy group: ${LEGACY_GROUP:-<not found>}"
echo "legacy home: $LEGACY_HOME"

echo -e "${YELLOW}[1/3] Creating /m target layout${NC}"
ensure_dir "$M_BASE_DIR" 755
ensure_dir "$MBIN_DIR" 755
ensure_dir "$WEB_BASE_DIR" 2755
ensure_dir "$LLAMA_DIR" 755
ensure_group "$WEB_GROUP"
ensure_user_in_group "$LEGACY_USER" "$WEB_GROUP"
ensure_owner "$MBIN_DIR" "$LEGACY_USER" "$LEGACY_GROUP"
ensure_owner "$LLAMA_DIR" "$LEGACY_USER" "$LEGACY_GROUP"
ensure_owner "$WEB_BASE_DIR" "root" "$WEB_GROUP"

echo -e "${YELLOW}[2/3] Creating global legacy symlinks${NC}"
ensure_link "/opt/mbin" "$MBIN_DIR"
ensure_link "/webs" "$WEB_BASE_DIR"

echo -e "${YELLOW}[3/3] Creating user-home legacy symlinks${NC}"
if [[ -d "$LEGACY_HOME" ]]; then
  ensure_dir "$LEGACY_HOME/ai" 755
  ensure_owner "$LEGACY_HOME/ai" "$LEGACY_USER" "$LEGACY_GROUP"
  ensure_link "$LEGACY_HOME/mbin" "$MBIN_DIR"
  ensure_link "$LEGACY_HOME/ai/llama.cpp" "$LLAMA_DIR"
else
  echo -e "${YELLOW}Skip user-home links: home directory not found: $LEGACY_HOME${NC}"
fi

echo -e "${GREEN}Done. /m compatibility symlinks are ready.${NC}"
