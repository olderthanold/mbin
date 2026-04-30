#!/usr/bin/env bash
# bai1_build_brew_llama.sh v01
set -euo pipefail

# Optional Homebrew-based llama.cpp setup.
# Main Linux build flow uses 0buildai.sh + bai1_build_llama.sh.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}==> Starting Homebrew-based llama.cpp setup${NC}"
echo -e "${GREEN}==> Step 1/3: Checking Homebrew availability${NC}"

if command -v brew >/dev/null 2>&1; then
  echo -e "${GREEN}==> Homebrew already installed${NC}"
else
  echo -e "${YELLOW}==> Homebrew not found. Installing Homebrew...${NC}"
  echo -e "${YELLOW}==> Running official installer: curl -fsSL <url> | /bin/bash (NONINTERACTIVE=1)${NC}"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  export PATH="/home/linuxbrew/.linuxbrew/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
fi

echo -e "${GREEN}==> Verifying Homebrew installation${NC}"
brew --version

echo -e "${GREEN}==> Installing/upgrading llama.cpp with Homebrew${NC}"
if brew list --formula | grep -q '^llama\.cpp$'; then
  echo -e "${GREEN}==> llama.cpp already installed; upgrading${NC}"
  brew upgrade llama.cpp
else
  echo -e "${GREEN}==> llama.cpp not installed; installing${NC}"
  brew install llama.cpp
fi

echo -e "${GREEN}==> Verifying llama.cpp installation${NC}"
brew list --formula | grep '^llama\.cpp$'

echo -e "${GREEN}==> Binary locations (if available on PATH)${NC}"
command -v llama-server || true
command -v llama-cli || true

echo -e "${GREEN}==> Done${NC}"
