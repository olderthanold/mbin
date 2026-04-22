#!/bin/bash
# Exit immediately if any command fails.
set -e

# Ensure local bin is in PATH (where uv and other user-local tools are installed).
export PATH="$HOME/.local/bin:$PATH"

# Green color code
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Step 1: Refresh apt package index metadata.
echo -e "${GREEN}==> Step 1/5: Updating apt package index...${NC}"
sudo apt update

# Additional SSL development dependency requested explicitly.
echo -e "${GREEN}==> Installing libssl-dev...${NC}"
sudo apt install libssl-dev

# Step 2: Install required packages.
# apt install -y:
#   -y automatically answers "yes" to prompts for non-interactive installs.
echo -e "${GREEN}==> Step 2/5: Installing dependencies (git, build-essential, cmake, python3, curl)...${NC}"
sudo apt install -y \
  git \
  build-essential \
  cmake \
  python3 \
  curl

# Install uv (Python package manager)
echo -e "${GREEN}==> Step 3/5: Ensuring uv is installed...${NC}"
if ! command -v uv &> /dev/null; then
    echo -e "${GREEN}Installing uv...${NC}"
    # curl options:
    # -L follow redirects, -s silent, -S show errors, -f fail on HTTP errors.
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    echo -e "${GREEN}uv is already installed.${NC}"
fi

# Print uv version to verify installation and PATH.
uv --version

# Handling llama.cpp (CPU Only)
echo -e "${GREEN}==> Step 4/5: Building/updating llama.cpp from source (CPU only)...${NC}"
# Check whether ~/ai exists before creating it.
if [ -d "$HOME/ai" ]; then
    echo -e "${GREEN}~/ai already exists.${NC}"
else
    echo -e "${GREEN}~/ai not found. Creating it now...${NC}"
    mkdir -p "$HOME/ai"
fi
echo "cd ~/ai"
cd ~/ai

REBUILD_REQUIRED=false

if [ -d "llama.cpp" ]; then
    echo -e "${GREEN}llama.cpp folder exists, checking for updates...${NC}"
    cd llama.cpp
    BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "none")
    git pull
    AFTER=$(git rev-parse HEAD)
    if [ "$BEFORE" != "$AFTER" ]; then
        echo -e "${GREEN}Updates downloaded, cleaning old build and preparing rebuild.${NC}"
        rm -rf build  # Remove old build artifacts to prevent growth/conflicts
        REBUILD_REQUIRED=true
    fi
else
    echo -e "${GREEN}Cloning llama.cpp...${NC}"
    git clone https://github.com/ggerganov/llama.cpp
    cd llama.cpp
    REBUILD_REQUIRED=true
fi

# Check if binaries exist
if [ ! -f "build/bin/llama-cli" ] || [ ! -f "build/bin/llama-server" ]; then
    echo -e "${GREEN}Binaries not found, build required.${NC}"
    REBUILD_REQUIRED=true
fi

if [ "$REBUILD_REQUIRED" = true ]; then
    echo -e "${GREEN}Building llama.cpp (CPU only)...${NC}"
    # cmake -B build: configure project and generate build files in ./build
    cmake -B build
    # --build build: compile using generated build system
    # -j$(nproc): parallelize build using all detected CPU cores
    cmake --build build -j$(nproc)
    echo -e "${GREEN}===== Build completed =====${NC}"
else
    echo -e "${GREEN}===== llama.cpp is already built and up to date =====${NC}"
fi

echo -e "${GREEN}==> Step 5/5: Final binary output paths${NC}"
echo -e "${GREEN}Binaries are located at:${NC}"
echo "$HOME/ai/llama.cpp/build/bin/llama-server"
echo "$HOME/ai/llama.cpp/build/bin/llama-cli"