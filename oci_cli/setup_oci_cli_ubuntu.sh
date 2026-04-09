#!/usr/bin/env bash

# ============================================================================
# OCI CLI setup script for Ubuntu (Oracle Cloud Free Tier VM friendly)
# ----------------------------------------------------------------------------
# What this script does:
#   1) Installs required OS packages
#   2) Downloads and runs Oracle's official OCI CLI installer (non-interactive)
#   3) Verifies that the `oci` command is available
#   4) Optionally starts `oci setup config` to help you configure credentials
#
# Usage:
#   chmod +x setup_oci_cli_ubuntu.sh
#   ./setup_oci_cli_ubuntu.sh
#
# This script is intended to be run as a regular Ubuntu user (for example
# user `ubuntu`) that has sudo privileges. You do NOT need `sudo -i`.
#
# Optional flags:
#   --configure      Start interactive OCI config setup at the end
#
# Example:
#   ./setup_oci_cli_ubuntu.sh --configure
# ============================================================================

set -euo pipefail

# -----------------------------
# Default configuration values
# -----------------------------
RUN_CONFIG_SETUP="false"

# -----------------------------
# Parse command-line arguments
# -----------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --configure)
      RUN_CONFIG_SETUP="true"
      shift
      ;;
    -h|--help)
      sed -n '1,35p' "$0"
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1"
      echo "Use --help to see available options."
      exit 1
      ;;
  esac
done

# -----------------------------
# Simple logger helper
# -----------------------------
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# ------------------------------------------------------------
# Safety check: this script must NOT be run as root
# ------------------------------------------------------------
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "[ERROR] Do not run this script with sudo or as root."
  echo "[ERROR] Run it as your normal user (e.g. ubuntu):"
  echo "        ./setup_oci_cli_ubuntu.sh --configure"
  echo
  echo "If you already ran with sudo and got /root/lib/oracle-cli conflicts, clean up with:"
  echo "  sudo rm -rf /root/lib/oracle-cli /root/bin/oci"
  exit 1
fi

# -----------------------------
# Ensure script runs on Ubuntu
# -----------------------------
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]]; then
    log "[WARN] This script is designed for Ubuntu. Detected ID=${ID:-unknown}."
    log "[WARN] Continuing anyway..."
  fi
else
  log "[WARN] /etc/os-release not found. Cannot verify OS. Continuing..."
fi

# -------------------------------------------------
# Ensure sudo access (needed for package installation)
# -------------------------------------------------
if ! command -v sudo >/dev/null 2>&1; then
  echo "[ERROR] sudo is required but not found."
  exit 1
fi

# NOTE:
# sudo password prompt is expected for package install steps.
# You do not need sudo -i, and should not run the whole script with sudo.

# -------------------------------------------
# Install prerequisite packages using apt-get
# -------------------------------------------
log "Updating package index..."
sudo apt-get update -y

log "Installing required packages (curl, python3, venv, pip, unzip, etc.)..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  curl \
  python3 \
  python3-venv \
  python3-pip \
  unzip \
  ca-certificates \
  less \
  groff \
  jq

# ------------------------------------------------------------
# Download Oracle's official OCI CLI installer to a temp file
# ------------------------------------------------------------
INSTALLER_SCRIPT="$(mktemp)"
trap 'rm -f "$INSTALLER_SCRIPT"' EXIT

log "Downloading OCI CLI installer script from Oracle GitHub repository..."
curl -fsSL https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh -o "$INSTALLER_SCRIPT"

# ------------------------------------------------------------------------
# Run installer non-interactively:
#   --accept-all-defaults avoids prompts
#
# NOTE:
# OCI installer argument parsing has changed across revisions:
#   - some versions accept: install.sh --accept-all-defaults
#   - others accept:       install.sh -- --accept-all-defaults
# We try both forms for maximum compatibility.
# ------------------------------------------------------------------------
log "Installing OCI CLI (non-interactive, portable mode)..."
INSTALL_OUTPUT_FILE="$(mktemp)"
trap 'rm -f "$INSTALLER_SCRIPT" "$INSTALL_OUTPUT_FILE"' EXIT

if bash "$INSTALLER_SCRIPT" --accept-all-defaults >"$INSTALL_OUTPUT_FILE" 2>&1; then
  log "OCI CLI installer accepted direct argument style."
elif grep -q "Install directory '/root/lib/oracle-cli' is not empty" "$INSTALL_OUTPUT_FILE"; then
  echo "[ERROR] OCI CLI was previously installed as root and left files in /root."
  echo "Fix and retry as normal user:"
  echo "  sudo rm -rf /root/lib/oracle-cli /root/bin/oci"
  echo "  ./setup_oci_cli_ubuntu.sh --configure"
  exit 1
elif bash "$INSTALLER_SCRIPT" -- --accept-all-defaults >"$INSTALL_OUTPUT_FILE" 2>&1; then
  log "OCI CLI installer accepted separator argument style."
else
  echo "[ERROR] OCI CLI installer failed with both known argument styles."
  echo "[ERROR] Installer output:"
  sed -n '1,120p' "$INSTALL_OUTPUT_FILE"
  echo "[ERROR] Try manual install test commands:"
  echo "  bash $INSTALLER_SCRIPT --help"
  echo "  bash $INSTALLER_SCRIPT --accept-all-defaults"
  exit 1
fi

# ---------------------------------------------------
# Ensure current shell can find `oci` immediately
# ---------------------------------------------------
# Try common installer locations first
OCI_BIN=""
for candidate in \
  "$HOME/bin/oci" \
  "$HOME/lib/oracle-cli/bin/oci" \
  "/usr/local/bin/oci"
do
  if [[ -x "$candidate" ]]; then
    OCI_BIN="$candidate"
    break
  fi
done

# Fall back to shell lookup if not found in common locations
if [[ -z "$OCI_BIN" ]] && command -v oci >/dev/null 2>&1; then
  OCI_BIN="$(command -v oci)"
fi

# If found, ensure PATH contains that directory for current and future sessions
if [[ -n "$OCI_BIN" ]]; then
  OCI_DIR="$(dirname "$OCI_BIN")"

  # Current shell
  case ":$PATH:" in
    *":$OCI_DIR:"*) ;;
    *) export PATH="$OCI_DIR:$PATH" ;;
  esac

  # Persist for future shells (idempotent)
  PATH_LINE="export PATH=\"$OCI_DIR:\$PATH\""
  if ! grep -Fq "$PATH_LINE" "$HOME/.bashrc" 2>/dev/null; then
    echo "$PATH_LINE" >> "$HOME/.bashrc"
  fi
  if ! grep -Fq "$PATH_LINE" "$HOME/.profile" 2>/dev/null; then
    echo "$PATH_LINE" >> "$HOME/.profile"
  fi
fi

# -----------------------
# Verify installation
# -----------------------
if command -v oci >/dev/null 2>&1; then
  log "OCI CLI installed successfully."
  log "OCI CLI version: $(oci --version)"
else
  echo "[ERROR] OCI CLI installation finished, but 'oci' command is not in PATH."
  echo "Attempt to find OCI binary manually:"
  echo "  find \"$HOME\" -type f -name oci 2>/dev/null | head"
  echo "Try one of these:"
  echo "  export PATH=\"$HOME/bin:\$PATH\""
  echo "  export PATH=\"/usr/local/bin:\$PATH\""
  exit 1
fi

# -----------------------------------------------------------------
# Optional: launch interactive config wizard to create ~/.oci/config
# -----------------------------------------------------------------
if [[ "$RUN_CONFIG_SETUP" == "true" ]]; then
  log "Starting interactive OCI configuration wizard..."
  log "You will need your Tenancy OCID, User OCID, Region, and API key."
  oci setup config
  log "Configuration wizard completed."
else
  log "Skipping OCI config wizard."
  log "When ready, run: oci setup config"
fi

log "Done. You can test with: oci os ns get"
