#!/usr/bin/env bash
# mgit_oldhttps.sh v01
set -euo pipefail

SCRIPT_NAME="mgit_oldhttps.sh"
SCRIPT_VERSION="v01"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

MBIN_DIR="${1:-/m/mbin}"
REMOTE_REPO="${2:-https://github.com/olderthanold/mbin.git}"
BRANCH="${3:-main}"

echo -e "${YELLOW}======================================================================${NC}"
echo -e "${YELLOW}Running $SCRIPT_NAME $SCRIPT_VERSION${NC}"
echo -e "${YELLOW}======================================================================${NC}"

if [[ -z "$MBIN_DIR" || "$MBIN_DIR" == "/" || "$MBIN_DIR" == "/m" ]]; then
  echo -e "${RED}Error: refusing unsafe target path: ${MBIN_DIR:-<empty>}${NC}"
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${YELLOW}Warning: not running as root; continuing if permissions are sufficient.${NC}"
fi

echo -e "${YELLOW}[1/4] Pulling $REMOTE_REPO ($BRANCH) into $MBIN_DIR via anonymous HTTPS${NC}"
if ! GIT_TERMINAL_PROMPT=0 git -C "$MBIN_DIR" pull "$REMOTE_REPO" "$BRANCH"; then
  echo -e "${YELLOW}[2/4] Pull failed. Recreating $MBIN_DIR from scratch.${NC}"
  rm -rf "$MBIN_DIR"
  GIT_TERMINAL_PROMPT=0 git clone -b "$BRANCH" "$REMOTE_REPO" "$MBIN_DIR"
fi

echo -e "${YELLOW}[3/4] Restoring executable permission on shell scripts in $MBIN_DIR${NC}"
chmod +x "$MBIN_DIR"/*.sh 2>/dev/null || true

echo -e "${YELLOW}[4/4] Ensuring ownership matches sudo user when available${NC}"
if [[ -n "${SUDO_USER:-}" && -d "$MBIN_DIR" ]]; then
  chown -R "$SUDO_USER:$(id -gn "$SUDO_USER")" "$MBIN_DIR"
fi

echo -e "${GREEN}Done: $SCRIPT_NAME workflow complete.${NC}"
