#!/usr/bin/env bash
# Exit behavior:
# -e : exit immediately on command failure (non-zero status)
# -u : treat unset variables as an error
# -o pipefail : fail a pipeline if any command in it fails
set -euo pipefail

# ------------------------------------------------------------
# ai_inst_brew.sh
# Purpose:
#  1) Ensure Homebrew is installed.
#  2) Install (or upgrade) llama.cpp via Homebrew.
#  3) Print verification details for brew + llama binaries.
# ------------------------------------------------------------

# Color codes for readable logs.
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}==> Starting Homebrew-based llama.cpp setup${NC}"
echo -e "${GREEN}==> Step 1/3: Checking Homebrew availability${NC}"

# Step 1: Check whether brew exists on PATH.
if command -v brew >/dev/null 2>&1; then
  echo -e "${GREEN}==> Homebrew already installed${NC}"
else
  echo -e "${YELLOW}==> Homebrew not found. Installing Homebrew...${NC}"
  # Run official Homebrew installer in non-interactive mode.
  # -fsSL: fail on HTTP errors, silent output, show errors, follow redirects.
  echo -e "${YELLOW}==> Running official installer: curl -fsSL <url> | /bin/bash (NONINTERACTIVE=1)${NC}"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add typical Homebrew locations to current PATH for immediate use.
  # Linux default: /home/linuxbrew/.linuxbrew/bin
  # macOS Apple Silicon default: /opt/homebrew/bin
  # macOS Intel default: /usr/local/bin
  export PATH="/home/linuxbrew/.linuxbrew/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
fi

echo -e "${GREEN}==> Verifying Homebrew installation${NC}"
# brew --version prints installed brew version and confirms command availability.
brew --version

# Step 2: Install or upgrade llama.cpp formula.
echo -e "${GREEN}==> Installing/upgrading llama.cpp with Homebrew${NC}"
# brew list --formula: list installed formulae (CLI packages)
# grep -q '^llama\.cpp$': quiet match for exact formula name
if brew list --formula | grep -q '^llama\.cpp$'; then
  echo -e "${GREEN}==> llama.cpp already installed; upgrading${NC}"
  # brew upgrade <formula>: upgrade existing formula to latest available version
  brew upgrade llama.cpp
else
  echo -e "${GREEN}==> llama.cpp not installed; installing${NC}"
  # brew install <formula>: install formula and dependencies
  brew install llama.cpp
fi

# Step 3: Verify installed package and binaries.
echo -e "${GREEN}==> Verifying llama.cpp installation${NC}"
# Exact-match verification that formula is now present.
brew list --formula | grep '^llama\.cpp$'

echo -e "${GREEN}==> Binary locations (if available on PATH)${NC}"
# command -v prints the resolved executable path if found.
command -v llama-server || true
command -v llama-cli || true

echo -e "${GREEN}==> Done${NC}"
