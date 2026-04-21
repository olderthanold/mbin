#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="git_web.sh"
SCRIPT_VERSION="v02"
SEP="======================================================================"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

show_help() {
  echo "Usage: $0 <domain|absolute_web_dir> [git_remote]"
  echo ""
  echo "Examples:"
  echo "  $0 example.com"
  echo "  $0 /webs/example.com"
  echo "  $0 example.com https://github.com/olderthanold/web.git"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

if [[ "$#" -lt 1 ]]; then
  show_help
  exit 1
fi

echo -e "${YELLOW}${SEP}${NC}"
echo -e "${YELLOW}Running $SCRIPT_NAME $SCRIPT_VERSION${NC}"
echo -e "${YELLOW}${SEP}${NC}"

# Resolve target directory from required argument:
# - Absolute Ubuntu path (starts with /): use as-is
# - Any other value: treat as domain and prepend /webs/
INPUT_TARGET="$1"
if [[ "$INPUT_TARGET" == /* ]]; then
  WEB_DIR="$INPUT_TARGET"
  DOMAIN="$(basename "$WEB_DIR")"
else
  DOMAIN="$INPUT_TARGET"
  WEB_DIR="/webs/$DOMAIN"
fi

# Optional second argument for Git remote URL.
GIT_LINK="${2:-https://github.com/olderthanold/web.git}"

if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo).${NC}"
  exit 1
fi

echo -e "${YELLOW}[1/5] Resolved target website directory and remote${NC}"
echo -e "${YELLOW}Domain: $DOMAIN${NC}"
echo -e "${YELLOW}Web directory: $WEB_DIR${NC}"
echo -e "${YELLOW}Git remote: $GIT_LINK${NC}"

echo -e "${YELLOW}[2/5] Pulling latest changes (origin main) into $WEB_DIR${NC}"
if ! git -C "$WEB_DIR" pull origin main; then
  echo -e "${YELLOW}Initial pull failed. Entering recovery flow: stash + pull --rebase + fallback clone${NC}"

  recovery_stash_ref=""
  recovery_stash_msg="git_mbin_autostash_$(date +%Y%m%d_%H%M%S)"

  # Stash only when there is local work to save.
  echo -e "${YELLOW}[3/5] Checking local changes before recovery${NC}"
  if [[ -n "$(git -C "$WEB_DIR" status --porcelain)" ]]; then
    git -C "$WEB_DIR" stash push -u -m "$recovery_stash_msg"
    recovery_stash_ref="$(git -C "$WEB_DIR" stash list | awk -v msg="$recovery_stash_msg" '$0 ~ msg {print $1; exit}')"
    echo -e "${GREEN}Created recovery stash: ${recovery_stash_ref:-<unknown>}${NC}"
  else
    echo -e "${YELLOW}No local changes detected; stash not needed.${NC}"
  fi

  echo -e "${YELLOW}[4/5] Attempting recovery pull --rebase (origin main)${NC}"
  if git -C "$WEB_DIR" pull --rebase origin main; then
    echo -e "${GREEN}Recovery pull --rebase succeeded.${NC}"
    if [[ -n "$recovery_stash_ref" ]]; then
      git -C "$WEB_DIR" stash drop "$recovery_stash_ref" >/dev/null || true
      echo -e "${GREEN}Dropped recovery stash: $recovery_stash_ref${NC}"
    fi
  else
    echo -e "${YELLOW}Recovery pull --rebase failed, recreating $WEB_DIR${NC}"
    rm -rf "$WEB_DIR"
    git clone -b main "$GIT_LINK" "$WEB_DIR"
  fi
fi

echo -e "${YELLOW}[5/5] Restoring executable permission on shell scripts in $WEB_DIR${NC}"
chmod +x "$WEB_DIR"/*.sh 2>/dev/null || true
echo -e "${GREEN}Done: $SCRIPT_NAME workflow complete.${NC}"

