#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="git_https.sh"
SCRIPT_VERSION="v03"
SEP="======================================================================"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
DEFAULT_LOCAL_PATH="/opt/mbin"
DEFAULT_REMOTE_REPO="https://github.com/olderthanold/web.git"

show_help() {
  echo "Usage: $0 [-h|--help] [-n <user>] [local_path] [remote_repo]"
  echo ""
  echo "Arguments:"
  echo "  local_path   Optional target repository path"
  echo "               - absolute path: use as-is"
  echo "               - relative path: resolved under HOME"
  echo "               - omitted: defaults to $DEFAULT_LOCAL_PATH"
  echo "  remote_repo  Optional HTTPS Git remote URL/path"
  echo "               - omitted: defaults to $DEFAULT_REMOTE_REPO"
  echo ""
  echo "Flags:"
  echo "  -n <user>    Add extra user for sudo-only group sync checks"
  echo "  -h, --help   Show this help and exit"
}

# Wrapper to run git commands over HTTPS.
# GIT_TERMINAL_PROMPT=1 allows interactive auth prompt for private repositories.
run_git_cmd() {
  GIT_TERMINAL_PROMPT=1 git "$@"
}

append_unique_user() {
  local user="$1"
  [[ -z "$user" ]] && return

  for existing in "${SYNC_USERS[@]:-}"; do
    if [[ "$existing" == "$user" ]]; then
      return
    fi
  done

  SYNC_USERS+=("$user")
}

ensure_user_in_group() {
  local user="$1"
  local group="$2"
  local source_label="$3"

  if ! id "$user" >/dev/null 2>&1; then
    echo -e "${RED}Error: user '$user' does not exist.${NC}"
    return 1
  fi

  if id -nG "$user" | tr ' ' '\n' | grep -Fxq "$group"; then
    echo -e "${GREEN}User '$user' is already in group '$group' (${source_label}).${NC}"
    return 0
  fi

  if [[ "${EUID}" -ne 0 ]]; then
    echo -e "${RED}Error: cannot modify groups without root. Please run with sudo.${NC}"
    return 1
  fi

  # -aG keeps existing groups (-a) and appends new supplementary group (-G).
  usermod -aG "$group" "$user"
  echo -e "${GREEN}Added user '$user' to group '$group' (${source_label}).${NC}"
}

ASSIGN_USER=""
POSITIONAL_ARGS=()
SYNC_USERS=()

# Parse optional flags first, then capture positional args.
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -n)
      if [[ $# -lt 2 || "$2" == -* ]]; then
        echo -e "${RED}Error: -n requires a user value.${NC}"
        show_help
        exit 1
      fi
      ASSIGN_USER="$2"
      shift 2
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        POSITIONAL_ARGS+=("$1")
        shift
      done
      ;;
    -*)
      echo -e "${RED}Error: unknown option '$1'.${NC}"
      show_help
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ "${#POSITIONAL_ARGS[@]}" -gt 2 ]]; then
  echo -e "${RED}Error: too many positional arguments.${NC}"
  show_help
  exit 1
fi

INPUT_LOCAL_PATH="${POSITIONAL_ARGS[0]:-}"
INPUT_REMOTE_REPO="${POSITIONAL_ARGS[1]:-}"

echo -e "${YELLOW}${SEP}${NC}"
echo -e "${YELLOW}Running $SCRIPT_NAME $SCRIPT_VERSION${NC}"
echo -e "${YELLOW}${SEP}${NC}"

# Resolve local path:
# - no arg: default /opt/mbin
# - absolute arg: use as-is
# - relative arg: resolve under HOME
if [[ -z "$INPUT_LOCAL_PATH" ]]; then
  WEB_DIR="$DEFAULT_LOCAL_PATH"
  echo -e "${YELLOW}[1/8] No local path provided. Using default: $WEB_DIR${NC}"
elif [[ "$INPUT_LOCAL_PATH" == /* ]]; then
  WEB_DIR="$INPUT_LOCAL_PATH"
  echo -e "${YELLOW}[1/8] Using absolute local path: $WEB_DIR${NC}"
else
  WEB_DIR="${HOME%/}/$INPUT_LOCAL_PATH"
  echo -e "${YELLOW}[1/8] Relative path resolved under HOME: $WEB_DIR${NC}"
fi

# Resolve remote repository:
# - no arg: default web HTTPS repo
# - provided: use as-is
GIT_LINK="${INPUT_REMOTE_REPO:-$DEFAULT_REMOTE_REPO}"
echo -e "${YELLOW}[2/8] Using remote repository: $GIT_LINK${NC}"
echo -e "${YELLOW}HTTPS mode: public repos work without login; private repos may prompt for credentials/token.${NC}"

# Check write access before any git operation.
echo -e "${YELLOW}[3/8] Checking write access for target path${NC}"
PARENT_DIR="$(dirname "$WEB_DIR")"
if [[ -e "$WEB_DIR" ]]; then
  if [[ ! -w "$WEB_DIR" ]]; then
    echo -e "${RED}Error: no write access to $WEB_DIR. Please run with sudo.${NC}"
    exit 1
  fi
else
  if [[ ! -d "$PARENT_DIR" ]]; then
    echo -e "${YELLOW}Parent directory does not exist: $PARENT_DIR${NC}"
    echo -e "${RED}Error: cannot prepare target path. Please run with sudo.${NC}"
    exit 1
  fi

  if [[ ! -w "$PARENT_DIR" ]]; then
    echo -e "${RED}Error: no write access to parent directory $PARENT_DIR. Please run with sudo.${NC}"
    exit 1
  fi
fi

# Ensure group-write permission on parent/target directories.
# chmod g+w => add group write bit while preserving other existing mode bits.
echo -e "${YELLOW}Ensuring group-write permission on parent directory: $PARENT_DIR${NC}"
if ! chmod g+w "$PARENT_DIR"; then
  echo -e "${RED}Error: failed to set group write on $PARENT_DIR (chmod g+w). Please run with sudo.${NC}"
  exit 1
fi

if [[ -d "$WEB_DIR" ]]; then
  echo -e "${YELLOW}Ensuring group-write permission on target directory: $WEB_DIR${NC}"
  if ! chmod g+w "$WEB_DIR"; then
    echo -e "${RED}Error: failed to set group write on $WEB_DIR (chmod g+w). Please run with sudo.${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}Target directory not present yet; group-write permission will be applied after git operations.${NC}"
fi

# Optional user/group synchronization (sudo-only):
# - always include sudo caller
# - include -n user too when provided
# - ensure users are in parent-dir group now, and target-dir group when available
echo -e "${YELLOW}[4/8] Processing group sync for sudo caller and optional -n user${NC}"
if [[ -n "${SUDO_USER:-}" ]]; then
  LOCAL_PARENT_DIR="$(dirname "$WEB_DIR")"
  append_unique_user "$SUDO_USER"
  append_unique_user "$ASSIGN_USER"

  if [[ "${#SYNC_USERS[@]}" -eq 0 ]]; then
    echo -e "${YELLOW}No users resolved for group sync.${NC}"
  else
    echo -e "${YELLOW}Users selected for group sync: ${SYNC_USERS[*]}${NC}"
    REPO_PARENT_GROUP="$(stat -c '%G' "$LOCAL_PARENT_DIR")"
    echo -e "${YELLOW}Parent path: $LOCAL_PARENT_DIR | Group: $REPO_PARENT_GROUP${NC}"

    for sync_user in "${SYNC_USERS[@]}"; do
      ensure_user_in_group "$sync_user" "$REPO_PARENT_GROUP" "parent:$LOCAL_PARENT_DIR" || exit 1
    done

    if [[ -d "$WEB_DIR" ]]; then
      TARGET_DIR_GROUP="$(stat -c '%G' "$WEB_DIR")"
      echo -e "${YELLOW}Target path: $WEB_DIR | Group: $TARGET_DIR_GROUP${NC}"
      for sync_user in "${SYNC_USERS[@]}"; do
        ensure_user_in_group "$sync_user" "$TARGET_DIR_GROUP" "target:$WEB_DIR" || exit 1
      done
    else
      echo -e "${YELLOW}Target directory does not exist yet; target-group sync will run after git operations.${NC}"
    fi
  fi
else
  echo -e "${YELLOW}Not running under sudo; skipping group sync logic.${NC}"
fi

# Check privilege level for visibility (script may still proceed if permissions suffice).
echo -e "${YELLOW}[5/8] Checking privileges (informational)${NC}"
if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${YELLOW}Info: running as non-root user.${NC}"
fi

# Pull latest changes from repository
echo -e "${YELLOW}[6/8] Pulling latest changes into $WEB_DIR${NC}"

if [[ ! -d "$WEB_DIR/.git" ]]; then
  echo -e "${YELLOW}Target is not a git repository yet. Cloning main branch.${NC}"
  run_git_cmd clone -b main "$GIT_LINK" "$WEB_DIR"
elif ! run_git_cmd -C "$WEB_DIR" pull "$GIT_LINK" main; then
  # Recovery mode if initial pull fails
  echo -e "${YELLOW}Initial pull failed. Entering recovery flow: stash + pull --rebase + fallback clone${NC}"

  recovery_stash_ref=""
  recovery_stash_msg="git_web_autostash_$(date +%Y%m%d_%H%M%S)"

  # Only stash if there are local changes to preserve
  echo -e "${YELLOW}[7/8] Checking local changes before recovery${NC}"
  if [[ -n "$(git -C "$WEB_DIR" status --porcelain)" ]]; then
    git -C "$WEB_DIR" stash push -u -m "$recovery_stash_msg"
    recovery_stash_ref="$(git -C "$WEB_DIR" stash list | awk -v msg="$recovery_stash_msg" '$0 ~ msg {print $1; exit}')"
    echo -e "${GREEN}Created recovery stash: ${recovery_stash_ref:-<unknown>}${NC}"
  else
    echo -e "${YELLOW}No local changes detected; stash not needed.${NC}"
  fi

  # Try pull with rebase to handle conflicts better
  echo -e "${YELLOW}[8/8] Attempting recovery pull --rebase${NC}"
  if run_git_cmd -C "$WEB_DIR" pull --rebase "$GIT_LINK" main; then
    echo -e "${GREEN}Recovery pull --rebase succeeded.${NC}"
    # Clean up the stash we created
    if [[ -n "$recovery_stash_ref" ]]; then
      git -C "$WEB_DIR" stash drop "$recovery_stash_ref" >/dev/null || true
      echo -e "${GREEN}Dropped recovery stash: $recovery_stash_ref${NC}"
    fi
  else
    # Last resort: recreate the directory entirely
    echo -e "${YELLOW}Recovery pull --rebase failed, recreating $WEB_DIR${NC}"
    rm -rf "$WEB_DIR"
    run_git_cmd clone -b main "$GIT_LINK" "$WEB_DIR"
  fi
fi

# If running with sudo, re-check target directory group after repo operations.
if [[ -n "${SUDO_USER:-}" && "${#SYNC_USERS[@]}" -gt 0 ]]; then
  if [[ -d "$WEB_DIR" ]]; then
    TARGET_DIR_GROUP_POST="$(stat -c '%G' "$WEB_DIR")"
    echo -e "${YELLOW}Post-update target path: $WEB_DIR | Group: $TARGET_DIR_GROUP_POST${NC}"
    for sync_user in "${SYNC_USERS[@]}"; do
      ensure_user_in_group "$sync_user" "$TARGET_DIR_GROUP_POST" "target-post:$WEB_DIR" || exit 1
    done
  else
    echo -e "${YELLOW}Post-update target directory missing; skipping target-group sync.${NC}"
  fi
fi

# Ensure target directory is group-writable after pull/clone/recovery flow.
echo -e "${YELLOW}Ensuring group-write permission on target directory after git operations: $WEB_DIR${NC}"
if [[ -d "$WEB_DIR" ]]; then
  if ! chmod g+w "$WEB_DIR"; then
    echo -e "${RED}Error: failed to set group write on $WEB_DIR after git operations (chmod g+w). Please run with sudo.${NC}"
    exit 1
  fi
else
  echo -e "${RED}Error: target directory missing after git operations: $WEB_DIR${NC}"
  exit 1
fi

# Restore executable permissions on all scripts after update
echo -e "${YELLOW}Restoring executable permission on shell scripts in $WEB_DIR${NC}"
chmod +x "$WEB_DIR"/*.sh 2>/dev/null || true
echo -e "${GREEN}Done: $SCRIPT_NAME workflow complete.${NC}"

