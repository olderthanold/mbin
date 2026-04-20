#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Require: new username
[[ $# -lt 1 ]] && { echo "Usage: sudo bash $0 <new_user> [source_user]"; exit 1; }
# Must run as root
[[ $EUID -ne 0 ]] && { echo "Run with sudo/root"; exit 1; }

echo -e "${YELLOW}Running init_2_user_clone_user.sh v01${NC}"

NEW_USER="$1"  # New account name
SOURCE_USER="${2:-${SUDO_USER:-$(id -un)}}"  # Source account

# Verify source exists
getent passwd "$SOURCE_USER" >/dev/null || { echo "Source user not found: $SOURCE_USER"; exit 1; }
# Stop if target exists
! getent passwd "$NEW_USER" >/dev/null || { echo "User already exists: $NEW_USER"; exit 1; }

SOURCE_HOME="$(getent passwd "$SOURCE_USER" | cut -d: -f6)"  # Source home
NEW_HOME="/home/$NEW_USER"  # Target home

useradd -m -s /bin/bash "$NEW_USER"  # Create user with bash shell
usermod -aG sudo "$NEW_USER"  # Add to sudo group

# Copy home files (skip cache/trash)
rsync -aHAX --exclude='.cache/' --exclude='.local/share/Trash/' "$SOURCE_HOME/" "$NEW_HOME/"

# Ensure .ssh exists with strict perms
install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "$NEW_HOME/.ssh"
if [[ -f "$SOURCE_HOME/.ssh/authorized_keys" ]]; then
  # Copy SSH login key
  install -m 600 -o "$NEW_USER" -g "$NEW_USER" "$SOURCE_HOME/.ssh/authorized_keys" "$NEW_HOME/.ssh/authorized_keys"
fi

chown -R "$NEW_USER:$NEW_USER" "$NEW_HOME"  # Final ownership fix
echo "Done: $NEW_USER cloned from $SOURCE_USER"  # Done message
