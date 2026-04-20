#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ini2sys_swap.sh v02
#
# Purpose:
#   Create and enable a 5G swap file, persist it in /etc/fstab,
#   and verify active swap state.

if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${RED}Error: run as root (use sudo), e.g.:${NC}"
  echo "  sudo bash $0"
  exit 1
fi

SWAPFILE="/swapfile"
SWAPSIZE="5G"
FSTAB_LINE="/swapfile none swap sw 0 0"

echo -e "${YELLOW}Running ini2sys_swap.sh v02${NC}"

# Detect whether this swapfile is already active to keep reruns safe.
if swapon --show=NAME --noheadings | grep -Fxq "${SWAPFILE}"; then
  SWAP_ACTIVE=1
else
  SWAP_ACTIVE=0
fi

echo -e "${YELLOW}[1/7] Creating swap file (${SWAPSIZE}) at ${SWAPFILE} (fallocate -l ${SWAPSIZE})${NC}"
# Create/resize swap file to requested size only when swapfile is not currently active.
if [[ "${SWAP_ACTIVE}" -eq 1 ]]; then
  echo "${SWAPFILE} is already active swap; skipping recreate/format steps."
else
  fallocate -l "${SWAPSIZE}" "${SWAPFILE}"
fi

echo -e "${YELLOW}[2/7] Setting secure permissions on ${SWAPFILE} (chmod 600)${NC}"
# Restrict file access for security.
chmod 600 "${SWAPFILE}"

echo -e "${YELLOW}[3/7] Formatting ${SWAPFILE} as swap (mkswap)${NC}"
# Initialize swap area metadata.
if [[ "${SWAP_ACTIVE}" -eq 1 ]]; then
  echo "${SWAPFILE} is already active swap; skipping mkswap."
else
  mkswap "${SWAPFILE}"
fi

echo -e "${YELLOW}[4/7] Enabling swap now (swapon ${SWAPFILE})${NC}"
# Activate swap immediately.
if [[ "${SWAP_ACTIVE}" -eq 1 ]]; then
  echo "${SWAPFILE} is already enabled."
else
  swapon "${SWAPFILE}"
fi

echo -e "${YELLOW}[5/7] Checking if fstab row already exists using grep${NC}"
# Keep operation idempotent by appending only when exact swap row is absent.
if grep -Eq '^/swapfile[[:space:]]+none[[:space:]]+swap[[:space:]]+sw[[:space:]]+0[[:space:]]+0([[:space:]]*#.*)?$' /etc/fstab; then
  echo "fstab entry already exists: ${FSTAB_LINE}"
else
  echo -e "${YELLOW}Adding persistent swap entry to /etc/fstab${NC}"
  echo "${FSTAB_LINE}" | tee -a /etc/fstab > /dev/null
fi

echo -e "${YELLOW}[6/7] Verifying active swap devices (swapon --show)${NC}"
swapon --show

echo -e "${YELLOW}[7/7] Verifying memory/swap totals (free -h)${NC}"
free -h

echo ""
echo -e "${GREEN}Swap setup complete.${NC}"
echo "Safe to run again (fstab append is guarded by grep check)."
