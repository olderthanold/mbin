#!/usr/bin/env bash
# =============================================================================
# git_mbin_ssh.sh - Automated repository management for /m/mbin directory
# Purpose: Keeps track of and updates multiple scripts/tools stored in /m/mbin
# Author: olderthanold (via m.git repository)
# =============================================================================

set -euo pipefail  # Exit on error, undefined variable, or pipeline failure

SCRIPT_NAME="git_mbin_ssh.sh"
SCRIPT_VERSION="v10"
# mgit_ssh.sh v10
SEP="======================================================================"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
DEFAULT_LOCAL_PATH="/m/mbin"
DEFAULT_REMOTE_REPO="git@github.com:olderthanold/mbin.git"
DEFAULT_GITHUB_OWNER="olderthanold"
SSH_KEY_PATH="/home/ubun2/.ssh/old.key"

show_help() {
  echo "Usage: $0 [-h|--help] [-n <user>] [local_path] [remote_repo]"
  echo ""
  echo "Arguments:"
  echo "  local_path   Optional target repository path"
  echo "               - absolute path: use as-is"
  echo "               - relative path: resolved under HOME"
  echo "               - omitted: defaults to $DEFAULT_LOCAL_PATH"
  echo "  remote_repo  Optional Git remote URL/path"
  echo "               - omitted: defaults to $DEFAULT_REMOTE_REPO"
  echo "               - short alias (e.g. 'mbin'): expands to git@github.com:${DEFAULT_GITHUB_OWNER}/<alias>.git"
  echo ""
  echo "Examples:"
  echo "  $0"
  echo "  $0 mm"
  echo "  $0 mm git@github.com:${DEFAULT_GITHUB_OWNER}/mbin.git"
  echo "  $0 mm mbin"
  echo ""
  echo "Flags:"
  echo "  -n <user>    Ensure <user> belongs to the group of local_path parent"
  echo "  -h, --help   Show this help and exit"
}

normalize_remote_repo() {
  local raw_remote="$1"

  if [[ -z "$raw_remote" ]]; then
    GIT_LINK="$DEFAULT_REMOTE_REPO"
    return 0
  fi

  # Accept explicit remote forms as-is:
  # - SSH scp-like: git@host:org/repo.git
  # - SSH URL: ssh://...
  # - HTTP(S) URL: http://... or https://...
  # - Local path (absolute, relative, existing filesystem path)
  # - Any value containing '/' or ':' (covers host/path and local repo patterns)
  if [[ "$raw_remote" == git@* || "$raw_remote" == ssh://* || "$raw_remote" == http://* || "$raw_remote" == https://* ]]; then
    GIT_LINK="$raw_remote"
    return 0
  fi

  if [[ "$raw_remote" == /* || "$raw_remote" == ./* || "$raw_remote" == ../* || -e "$raw_remote" ]]; then
    GIT_LINK="$raw_remote"
    return 0
  fi

  if [[ "$raw_remote" == *"/"* || "$raw_remote" == *":"* || "$raw_remote" == *.git ]]; then
    GIT_LINK="$raw_remote"
    return 0
  fi

  # Bare token shorthand (e.g. "mbin") is treated as GitHub repo alias.
  if [[ "$raw_remote" =~ ^[A-Za-z0-9._-]+$ ]]; then
    GIT_LINK="git@github.com:${DEFAULT_GITHUB_OWNER}/${raw_remote}.git"
    echo -e "${YELLOW}Remote alias '$raw_remote' expanded to: $GIT_LINK${NC}"
    return 0
  fi

  echo -e "${RED}Error: unsupported remote format '$raw_remote'.${NC}"
  echo -e "${RED}Use a full remote URL/path or a simple alias like 'mbin'.${NC}"
  return 1
}

# Wrapper to run git commands with SSH key only for SSH-style remotes.
run_git_cmd() {
  if [[ "$GIT_LINK" == git@* || "$GIT_LINK" == ssh://* ]]; then
    GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o IdentitiesOnly=yes" git "$@"
  else
    git "$@"
  fi
}

GIT_LAST_OUTPUT=""

run_git_cmd_capture() {
  local log_file rc
  log_file="$(mktemp)"

  set +e
  run_git_cmd "$@" 2>&1 | tee "$log_file"
  rc="${PIPESTATUS[0]}"
  set -e

  GIT_LAST_OUTPUT="$(cat "$log_file")"
  rm -f "$log_file"
  return "$rc"
}

is_ssh_auth_failure_output() {
  local output="$1"

  grep -Eiq \
    "(Load key .*(error in libcrypto|invalid format)|Permission denied \(publickey\)|"\
"Could not read from remote repository|Host key verification failed)" \
    <<<"$output"
}

abort_ssh_auth_failure_without_recovery() {
  echo -e "${RED}Error: SSH authentication/key failure detected.${NC}"
  echo -e "${RED}Stopping before recovery flow so $MBIN_DIR is not stashed/rebased/recreated.${NC}"
  echo -e "${YELLOW}If the key was copied from Windows, remove CRLF endings:${NC}"
  echo "  cp -p \"$SSH_KEY_PATH\" \"$SSH_KEY_PATH.bak_\$(date +%Y%m%d_%H%M%S)\""
  echo "  sed -i 's/\\r$//' \"$SSH_KEY_PATH\""
  echo "  chmod 600 \"$SSH_KEY_PATH\""
  echo "  ssh-keygen -y -f \"$SSH_KEY_PATH\" >/tmp/old.pub"
  exit 1
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

resolve_owner_group() {
  OWNER_USER="${ASSIGN_USER:-${SUDO_USER:-$USER}}"

  if ! id "$OWNER_USER" >/dev/null 2>&1; then
    echo -e "${RED}Error: ownership target user '$OWNER_USER' does not exist.${NC}"
    return 1
  fi

  OWNER_GROUP="$(id -gn "$OWNER_USER")"
  echo -e "${YELLOW}Ownership target resolved: $OWNER_USER:$OWNER_GROUP${NC}"
}

normalize_repo_ownership() {
  local repo_dir="$1"
  local phase_label="$2"

  [[ ! -e "$repo_dir" ]] && return 0

  local current_owner current_group mismatch_path git_write_problem
  current_owner="$(stat -c '%U' "$repo_dir")"
  current_group="$(stat -c '%G' "$repo_dir")"
  mismatch_path="$(find "$repo_dir" \( ! -user "$OWNER_USER" -o ! -group "$OWNER_GROUP" \) -print -quit 2>/dev/null || true)"
  git_write_problem=""

  if [[ -d "$repo_dir/.git" ]]; then
    if [[ -n "$(find "$repo_dir/.git" -maxdepth 0 ! -perm -0700 -print -quit 2>/dev/null || true)" ]]; then
      git_write_problem="$repo_dir/.git"
    elif [[ -e "$repo_dir/.git/FETCH_HEAD" && -n "$(find "$repo_dir/.git/FETCH_HEAD" -maxdepth 0 ! -perm -0600 -print -quit 2>/dev/null || true)" ]]; then
      git_write_problem="$repo_dir/.git/FETCH_HEAD"
    elif [[ -e "$repo_dir/.git/index" && -n "$(find "$repo_dir/.git/index" -maxdepth 0 ! -perm -0600 -print -quit 2>/dev/null || true)" ]]; then
      git_write_problem="$repo_dir/.git/index"
    elif [[ -d "$repo_dir/.git/objects" && -n "$(find "$repo_dir/.git/objects" -maxdepth 0 ! -perm -0700 -print -quit 2>/dev/null || true)" ]]; then
      git_write_problem="$repo_dir/.git/objects"
    elif [[ -d "$repo_dir/.git/refs" && -n "$(find "$repo_dir/.git/refs" -maxdepth 0 ! -perm -0700 -print -quit 2>/dev/null || true)" ]]; then
      git_write_problem="$repo_dir/.git/refs"
    fi
  fi

  echo -e "${YELLOW}[$phase_label] Ownership check for $repo_dir | current=$current_owner:$current_group | target=$OWNER_USER:$OWNER_GROUP${NC}"

  if [[ "$current_owner" == "$OWNER_USER" && "$current_group" == "$OWNER_GROUP" && -z "$mismatch_path" && -z "$git_write_problem" ]]; then
    echo -e "${GREEN}[$phase_label] Ownership already matches target.${NC}"
    return 0
  fi

  if [[ "${EUID}" -ne 0 ]]; then
    if [[ -n "$mismatch_path" ]]; then
      echo -e "${RED}Error: cannot normalize nested ownership without sudo.${NC}"
      echo -e "${RED}First mismatched path: $mismatch_path${NC}"
      echo -e "${RED}Current root: $current_owner:$current_group | Required tree: $OWNER_USER:$OWNER_GROUP | Path: $repo_dir${NC}"
      echo -e "${RED}Run with sudo (optionally -n $OWNER_USER) and retry.${NC}"
      return 1
    fi

    echo -e "${YELLOW}[$phase_label] Git metadata is not writable: $git_write_problem${NC}"
    echo -e "${YELLOW}[$phase_label] Attempting permission repair without sudo: chmod -R u+rwX,g+rwX $repo_dir/.git${NC}"
    if ! chmod -R u+rwX,g+rwX "$repo_dir/.git"; then
      echo -e "${RED}Error: failed to repair git metadata permissions without sudo.${NC}"
      echo -e "${RED}Run with sudo (optionally -n $OWNER_USER) and retry.${NC}"
      return 1
    fi
    echo -e "${GREEN}[$phase_label] Git metadata permissions repaired.${NC}"
    return 0
  fi

  # chown -R recursively applies the requested user:group ownership to repo path.
  echo -e "${YELLOW}[$phase_label] Running: chown -R $OWNER_USER:$OWNER_GROUP $repo_dir${NC}"
  chown -R "$OWNER_USER:$OWNER_GROUP" "$repo_dir"

  # chmod -R u+rwX,g+rwX grants owner/group rw and adds execute only where appropriate.
  echo -e "${YELLOW}[$phase_label] Running: chmod -R u+rwX,g+rwX $repo_dir${NC}"
  chmod -R u+rwX,g+rwX "$repo_dir"

  echo -e "${GREEN}[$phase_label] Ownership/permissions normalization complete for $repo_dir.${NC}"
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

OWNER_USER=""
OWNER_GROUP=""

resolve_owner_group || exit 1

echo -e "${YELLOW}${SEP}${NC}"
echo -e "${YELLOW}Running $SCRIPT_NAME $SCRIPT_VERSION${NC}"
echo -e "${YELLOW}${SEP}${NC}"

# Resolve local path:
# - no arg: default /m/mbin
# - absolute arg: use as-is
# - relative arg: resolve under HOME
if [[ -z "$INPUT_LOCAL_PATH" ]]; then
  MBIN_DIR="$DEFAULT_LOCAL_PATH"
  echo -e "${YELLOW}[1/8] No local path provided. Using default: $MBIN_DIR${NC}"
elif [[ "$INPUT_LOCAL_PATH" == /* ]]; then
  MBIN_DIR="$INPUT_LOCAL_PATH"
  echo -e "${YELLOW}[1/8] Using absolute local path: $MBIN_DIR${NC}"
else
  MBIN_DIR="${HOME%/}/$INPUT_LOCAL_PATH"
  echo -e "${YELLOW}[1/8] Relative path resolved under HOME: $MBIN_DIR${NC}"
fi

# Resolve remote repository:
# - no arg: default mbin SSH repo
# - explicit URL/path: use as-is
# - short alias token (e.g. "mbin"): expand to git@github.com:<owner>/<alias>.git
GIT_LINK=""
normalize_remote_repo "$INPUT_REMOTE_REPO" || exit 1
echo -e "${YELLOW}[2/8] Using remote repository: $GIT_LINK${NC}"

# Validate SSH key presence/permissions for SSH remotes:
# - if key is missing, stop early
# - if permissions are too open, fix to 600 and continue
if [[ "$GIT_LINK" == git@* || "$GIT_LINK" == ssh://* ]]; then
  echo -e "${YELLOW}Validating SSH key file: $SSH_KEY_PATH${NC}"

  if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo -e "${RED}Error: SSH key not found at $SSH_KEY_PATH${NC}"
    echo -e "${RED}Please provide the key file, then run again.${NC}"
    exit 1
  fi

  if [[ ! -r "$SSH_KEY_PATH" ]]; then
    echo -e "${RED}Error: SSH key exists but is not readable: $SSH_KEY_PATH${NC}"
    echo -e "${RED}Please fix read permissions (or run with sudo), then run again.${NC}"
    exit 1
  fi

  KEY_MODE="$(stat -c '%a' "$SSH_KEY_PATH" 2>/dev/null || true)"
  if [[ -z "$KEY_MODE" ]]; then
    echo -e "${RED}Error: unable to read SSH key permissions for $SSH_KEY_PATH${NC}"
    exit 1
  fi

  if [[ "$KEY_MODE" != "600" ]]; then
    echo -e "${YELLOW}SSH key permissions are $KEY_MODE (expected 600). Fixing...${NC}"
    if chmod 600 "$SSH_KEY_PATH"; then
      echo -e "${GREEN}SSH key permissions fixed to 600. Continuing.${NC}"
    else
      echo -e "${RED}Error: failed to set SSH key permissions to 600. Please run with sudo.${NC}"
      exit 1
    fi
  else
    echo -e "${GREEN}SSH key permissions are correct (600).${NC}"
  fi

  echo -e "${YELLOW}Checking SSH key can be parsed by ssh-keygen...${NC}"
  key_check_log="$(mktemp)"
  if ssh-keygen -y -f "$SSH_KEY_PATH" >/dev/null 2>"$key_check_log"; then
    rm -f "$key_check_log"
    echo -e "${GREEN}SSH key parses successfully.${NC}"
  else
    echo -e "${RED}Error: SSH key cannot be parsed by ssh-keygen.${NC}"
    cat "$key_check_log"
    rm -f "$key_check_log"

    if grep -q $'\r' "$SSH_KEY_PATH"; then
      echo -e "${YELLOW}CRLF line endings detected in SSH key. Fix with:${NC}"
    else
      echo -e "${YELLOW}No CRLF bytes detected. The key may be incomplete, pasted incorrectly, encrypted with an unsupported format, or not an OpenSSH private key.${NC}"
      echo -e "${YELLOW}If it came from Windows, this CRLF-safe rewrite is still OK to try:${NC}"
    fi

    echo "  cp -p \"$SSH_KEY_PATH\" \"$SSH_KEY_PATH.bak_\$(date +%Y%m%d_%H%M%S)\""
    echo "  sed -i 's/\\r$//' \"$SSH_KEY_PATH\""
    echo "  chmod 600 \"$SSH_KEY_PATH\""
    echo "  ssh-keygen -y -f \"$SSH_KEY_PATH\" >/tmp/old.pub"
    exit 1
  fi
fi

# Check write access before any git operation.
echo -e "${YELLOW}[3/8] Checking write access for target path${NC}"
PARENT_DIR="$(dirname "$MBIN_DIR")"
if [[ -e "$MBIN_DIR" ]]; then
  if [[ ! -w "$MBIN_DIR" ]]; then
    echo -e "${RED}Error: no write access to $MBIN_DIR. Please run with sudo.${NC}"
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
if [[ -w "$PARENT_DIR" ]]; then
  echo -e "${GREEN}Parent directory is already writable: $PARENT_DIR${NC}"
elif [[ ! -d "$MBIN_DIR" ]]; then
  echo -e "${YELLOW}Parent directory is not writable and target does not exist yet. Attempting chmod g+w on: $PARENT_DIR${NC}"
  if ! chmod g+w "$PARENT_DIR"; then
    echo -e "${RED}Error: failed to set group write on $PARENT_DIR (chmod g+w). Please run with sudo.${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}Parent directory is not writable ($PARENT_DIR), but target exists so continuing. Fallback clone may require sudo if recreate is needed.${NC}"
fi

if [[ -d "$MBIN_DIR" ]]; then
  if [[ -w "$MBIN_DIR" ]]; then
    echo -e "${GREEN}Target directory is already writable: $MBIN_DIR${NC}"
  else
    echo -e "${YELLOW}Target directory is not writable. Attempting chmod g+w on: $MBIN_DIR${NC}"
    if ! chmod g+w "$MBIN_DIR"; then
      echo -e "${RED}Error: failed to set group write on $MBIN_DIR (chmod g+w). Please run with sudo.${NC}"
      exit 1
    fi
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
  LOCAL_PARENT_DIR="$(dirname "$MBIN_DIR")"
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

    if [[ -d "$MBIN_DIR" ]]; then
      TARGET_DIR_GROUP="$(stat -c '%G' "$MBIN_DIR")"
      echo -e "${YELLOW}Target path: $MBIN_DIR | Group: $TARGET_DIR_GROUP${NC}"
      for sync_user in "${SYNC_USERS[@]}"; do
        ensure_user_in_group "$sync_user" "$TARGET_DIR_GROUP" "target:$MBIN_DIR" || exit 1
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

# Pull latest changes from GitHub repository
echo -e "${YELLOW}[6/8] Pulling latest changes into $MBIN_DIR${NC}"

# For existing repositories, enforce expected owner/group before git touches the path.
if [[ -d "$MBIN_DIR/.git" ]]; then
  normalize_repo_ownership "$MBIN_DIR" "pre-git" || exit 1
fi

if [[ ! -d "$MBIN_DIR/.git" ]]; then
  echo -e "${YELLOW}Target is not a git repository yet. Cloning main branch.${NC}"
  run_git_cmd clone -b main "$GIT_LINK" "$MBIN_DIR"
elif ! run_git_cmd_capture -C "$MBIN_DIR" pull "$GIT_LINK" main; then
  if [[ "$GIT_LINK" == git@* || "$GIT_LINK" == ssh://* ]] && is_ssh_auth_failure_output "$GIT_LAST_OUTPUT"; then
    abort_ssh_auth_failure_without_recovery
  fi

  # Recovery mode if initial pull fails
  echo -e "${YELLOW}Initial pull failed. Entering recovery flow: stash + pull --rebase + fallback clone${NC}"

  recovery_stash_ref=""
  recovery_stash_msg="git_gbin_autostash_$(date +%Y%m%d_%H%M%S)"

  # Only stash if there are local changes to preserve
  echo -e "${YELLOW}[7/8] Checking local changes before recovery${NC}"
  if [[ -n "$(git -C "$MBIN_DIR" status --porcelain)" ]]; then
    git -C "$MBIN_DIR" stash push -u -m "$recovery_stash_msg"
    recovery_stash_ref="$(git -C "$MBIN_DIR" stash list | awk -v msg="$recovery_stash_msg" '$0 ~ msg {print $1; exit}')"
    echo -e "${GREEN}Created recovery stash: ${recovery_stash_ref:-<unknown>}${NC}"
  else
    echo -e "${YELLOW}No local changes detected; stash not needed.${NC}"
  fi

  # Try pull with rebase to handle conflicts better
  echo -e "${YELLOW}[8/8] Attempting recovery pull --rebase${NC}"
  if run_git_cmd_capture -C "$MBIN_DIR" pull --rebase "$GIT_LINK" main; then
    echo -e "${GREEN}Recovery pull --rebase succeeded.${NC}"
    # Clean up the stash we created
    if [[ -n "$recovery_stash_ref" ]]; then
      git -C "$MBIN_DIR" stash drop "$recovery_stash_ref" >/dev/null || true
      echo -e "${GREEN}Dropped recovery stash: $recovery_stash_ref${NC}"
    fi
  else
    if [[ "$GIT_LINK" == git@* || "$GIT_LINK" == ssh://* ]] && is_ssh_auth_failure_output "$GIT_LAST_OUTPUT"; then
      abort_ssh_auth_failure_without_recovery
    fi

    # Last resort: recreate the directory entirely
    echo -e "${YELLOW}Recovery pull --rebase failed, recreating $MBIN_DIR${NC}"
    if [[ "${EUID}" -ne 0 ]]; then
      echo -e "${RED}Error: fallback recreate requires sudo/root due potential ownership mismatch in $MBIN_DIR.${NC}"
      exit 1
    fi
    rm -rf "$MBIN_DIR"
    run_git_cmd clone -b main "$GIT_LINK" "$MBIN_DIR"
  fi
fi

# Normalize ownership/permissions again after clone/pull/recovery.
if [[ -d "$MBIN_DIR" ]]; then
  normalize_repo_ownership "$MBIN_DIR" "post-git" || exit 1
fi

# If running with sudo, re-check target directory group after repo operations.
if [[ -n "${SUDO_USER:-}" && "${#SYNC_USERS[@]}" -gt 0 ]]; then
  if [[ -d "$MBIN_DIR" ]]; then
    TARGET_DIR_GROUP_POST="$(stat -c '%G' "$MBIN_DIR")"
    echo -e "${YELLOW}Post-update target path: $MBIN_DIR | Group: $TARGET_DIR_GROUP_POST${NC}"
    for sync_user in "${SYNC_USERS[@]}"; do
      ensure_user_in_group "$sync_user" "$TARGET_DIR_GROUP_POST" "target-post:$MBIN_DIR" || exit 1
    done
  else
    echo -e "${YELLOW}Post-update target directory missing; skipping target-group sync.${NC}"
  fi
fi

# Ensure target directory is group-writable after pull/clone/recovery flow.
echo -e "${YELLOW}Ensuring group-write permission on target directory after git operations: $MBIN_DIR${NC}"
if [[ -d "$MBIN_DIR" ]]; then
  if [[ -w "$MBIN_DIR" ]]; then
    echo -e "${GREEN}Target directory is writable after git operations: $MBIN_DIR${NC}"
  else
    echo -e "${YELLOW}Target directory is still not writable after git operations. Attempting chmod g+w.${NC}"
    if ! chmod g+w "$MBIN_DIR"; then
      echo -e "${RED}Error: failed to set group write on $MBIN_DIR after git operations (chmod g+w). Please run with sudo.${NC}"
      exit 1
    fi
  fi
else
  echo -e "${RED}Error: target directory missing after git operations: $MBIN_DIR${NC}"
  exit 1
fi

# Restore executable permissions on all scripts after update
echo -e "${YELLOW}Restoring executable permission on shell scripts in $MBIN_DIR${NC}"
chmod +x "$MBIN_DIR"/*.sh 2>/dev/null || true
echo -e "${GREEN}Done: $SCRIPT_NAME workflow complete.${NC}"
