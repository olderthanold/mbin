#!/bin/bash
set -e

# Ensure local bin is in PATH (where uv and other local tools are installed)
export PATH="$HOME/.local/bin:$PATH"

# Green color code
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Updating package index...${NC}"
sudo apt update

echo -e "${GREEN}Installing dependencies: git, build-essential, cmake, python3, curl...${NC}"
sudo apt install -y \
  git \
  build-essential \
  cmake \
  python3 \
  curl

# Install uv (Python package manager)
if ! command -v uv &> /dev/null; then
    echo -e "${GREEN}Installing uv...${NC}"
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    echo -e "${GREEN}uv is already installed.${NC}"
fi

uv --version

# Handling llama.cpp (CPU Only)
mkdir -p ~/ai
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
    cmake -B build
    cmake --build build -j$(nproc)
    echo -e "${GREEN}===== Build completed =====${NC}"
else
    echo -e "${GREEN}===== llama.cpp is already built and up to date =====${NC}"
fi

echo -e "${GREEN}Binaries are located at:${NC}"
echo "$HOME/ai/llama.cpp/build/bin/llama-server"
echo "$HOME/ai/llama.cpp/build/bin/llama-cli"