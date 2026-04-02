#!/usr/bin/env bash
# Use bash shell from environment

# Exit immediately on error (-e), treat unset variables as error (-u),
# and fail pipelines if any command fails (pipefail)
set -euo pipefail

# Print help text when arguments are missing
usage() {
  echo "Usage: sudo bash $0 <new_user> [source_user]"
  echo "Example: sudo bash $0 ubun2 ubuntu"
}

# Require at least one argument: the new username
if [[ ${1:-} == "" ]]; then
  usage
  exit 1
fi

# New account to create
NEW_USER="$1"
# Source account to copy from (defaults to sudo user / current user)
SOURCE_USER="${2:-${SUDO_USER:-$(id -un)}}"

# Validate username format for safety and Linux compatibility
if ! [[ "$NEW_USER" =~ ^[a-z][a-z0-9_-]*$ ]]; then
  echo "Error: Invalid new username '$NEW_USER'"
  echo "Allowed pattern: starts with letter, then letters/digits/_/-"
  exit 1
fi

# Must be run with sudo/root because we create users and edit ownership
if [[ "$EUID" -ne 0 ]]; then
  echo "Error: Run as root (use sudo)."
  exit 1
fi

# Verify source user exists
if ! getent passwd "$SOURCE_USER" >/dev/null; then
  echo "Error: Source user '$SOURCE_USER' does not exist."
  exit 1
fi

# Stop if target user already exists (as requested)
if getent passwd "$NEW_USER" >/dev/null; then
  echo "Error: User '$NEW_USER' already exists. Stopping."
  exit 1
fi

# Resolve source and target home directories
SOURCE_HOME="$(getent passwd "$SOURCE_USER" | cut -d: -f6)"
NEW_HOME="/home/$NEW_USER"

# Create new user with home directory and bash shell
echo "Creating user '$NEW_USER'..."
useradd -m -s /bin/bash "$NEW_USER"
# Add new user to sudo (admin) group
usermod -aG sudo "$NEW_USER"

# Ensure passwordless sudo rule exists for this user (idempotent check)
# We check main sudoers and all files in /etc/sudoers.d for:
#   <user> ALL=(ALL) NOPASSWD:ALL
SUDOERS_LINE="$NEW_USER ALL=(ALL) NOPASSWD:ALL"
if grep -RqsE "^[[:space:]]*${NEW_USER}[[:space:]]+ALL=\(ALL\)[[:space:]]+NOPASSWD:ALL([[:space:]]*#.*)?$" /etc/sudoers /etc/sudoers.d 2>/dev/null; then
  echo "Passwordless sudo rule already present for '$NEW_USER'."
else
  SUDOERS_FILE="/etc/sudoers.d/90-${NEW_USER}-nopasswd"
  echo "Adding passwordless sudo rule for '$NEW_USER'..."
  echo "$SUDOERS_LINE" > "$SUDOERS_FILE"
  chmod 440 "$SUDOERS_FILE"
  # Validate file syntax before continuing
  visudo -cf "$SUDOERS_FILE" >/dev/null
fi

# Copy source home content to new home.
# Excludes cache/trash to avoid unnecessary junk copy.
echo "Copying home from '$SOURCE_USER' to '$NEW_USER'..."
rsync -aHAX --exclude='.cache/' --exclude='.local/share/Trash/' "$SOURCE_HOME/" "$NEW_HOME/"

# Ensure .ssh folder exists with strict permissions
echo "Copying SSH authorized keys..."
install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "$NEW_HOME/.ssh"
# Copy authorized_keys so the same SSH key can log in as new user
if [[ -f "$SOURCE_HOME/.ssh/authorized_keys" ]]; then
  install -m 600 -o "$NEW_USER" -g "$NEW_USER" "$SOURCE_HOME/.ssh/authorized_keys" "$NEW_HOME/.ssh/authorized_keys"
else
  echo "Warning: '$SOURCE_HOME/.ssh/authorized_keys' not found."
fi

# Final ownership fix: make sure everything in new home belongs to new user
chown -R "$NEW_USER:$NEW_USER" "$NEW_HOME"

# Final status and reminder to test access before hardening old account
echo "Done. User '$NEW_USER' created, home copied, and SSH key access copied (if found)."
echo "Test login before disabling old account: ssh -i <keyfile> $NEW_USER@<vm_ip>"
