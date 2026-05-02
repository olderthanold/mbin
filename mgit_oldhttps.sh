#!/usr/bin/env bash
# mgit_oldhttps.sh v01
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

MBIN_DIR="${1:-/m/mbin}"
PARENT_DIR="$(dirname "$MBIN_DIR")"
REMOTE_REPO="${2:-https://github.com/olderthanold/mbin.git}"
BRANCH="${3:-main}"

echo -e "${YELLOW}======================================================================${NC}"
echo -e "${YELLOW}Running mgit_oldhttps.sh v02${NC}"
echo -e "${YELLOW}Use mgit_oldhttps.sh <target_dir> <hit_https> <branch>${NC}"
echo -e "${YELLOW}======================================================================${NC}"

if [[ -z "$MBIN_DIR" || "$MBIN_DIR" == "/" || "$MBIN_DIR" == "/m" ]]; then
  echo -e "${RED}Error: refusing unsafe target path: ${MBIN_DIR:-<empty>}${NC}"
  exit 1
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
if [[ -n "${SUDO_USER:-}" && -d "$MBIN_DIR" ]] \
  && SUDO_UID_NUM="$(id -u "$SUDO_USER")" \
  && MBIN_OWNER_UID="$(stat -c '%u' "$MBIN_DIR")" \
  && [[ "$MBIN_OWNER_UID" != "$SUDO_UID_NUM" ]]; then
  SUDO_GROUP="$(id -gn "$SUDO_USER")"
  chown -R "$SUDO_USER:$SUDO_GROUP" "$MBIN_DIR"
  chmod u+rwx,g+rwx "$PARENT_DIR"
  chown -R "$SUDO_USER:$SUDO_GROUP" "$PARENT_DIR"
  chmod u+rwx,g+rwx "$PARENT_DIR"
fi

echo -e "${GREEN}Done: mgit_oldhttps.sh workflow complete.${NC}"
