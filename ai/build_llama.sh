#!/usr/bin/env bash
# build_llama.sh v03
set -euo pipefail

# Ensure local bin is in PATH (where uv and other user-local tools are installed).
export PATH="$HOME/.local/bin:$PATH"
LLAMA_DIR="${LLAMA_DIR:-/m/llama.cpp}"
LLAMA_PARENT="$(dirname "$LLAMA_DIR")"
LLAMA_REPO_URL="${LLAMA_REPO_URL:-https://github.com/ggml-org/llama.cpp}"
OWNER_USER="${SUDO_USER:-${USER:-$(whoami)}}"
OWNER_GROUP="$(id -gn "$OWNER_USER" 2>/dev/null || echo "$OWNER_USER")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info() {
    echo -e "${YELLOW}$*${NC}"
}

ok() {
    echo -e "${GREEN}OK: $*${NC}"
}

fail() {
    echo -e "${RED}ERROR: $*${NC}"
}

info "Running build_llama.sh v03"

# Step 1: Refresh apt package index metadata.
info "==> Step 1/5: Updating apt package index..."
sudo apt-get update

# Step 2: Install required packages.
# apt install -y:
#   -y automatically answers "yes" to prompts for non-interactive installs.
info "==> Step 2/5: Installing dependencies (git, build-essential, cmake, python3, curl, libssl-dev)..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git \
  build-essential \
  cmake \
  python3 \
  curl \
  libssl-dev

# Install uv (Python package manager)
info "==> Step 3/5: Ensuring uv is installed..."
if ! command -v uv &> /dev/null; then
    info "Installing uv..."
    # curl options:
    # -L follow redirects, -s silent, -S show errors, -f fail on HTTP errors.
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    ok "uv is already installed."
fi

# Print uv version to verify installation and PATH.
uv --version

# Handling llama.cpp (CPU Only)
info "==> Step 4/5: Building/updating llama.cpp from source (CPU only)..."
# Check whether target path exists before creating it.
if [ -d "$LLAMA_DIR" ]; then
    ok "$LLAMA_DIR already exists."
else
    info "$LLAMA_DIR not found. Creating it now..."
    sudo mkdir -p "$LLAMA_DIR"
    sudo chown "$OWNER_USER:$OWNER_GROUP" "$LLAMA_DIR"
fi

if [ ! -w "$LLAMA_DIR" ]; then
    info "$LLAMA_DIR is not writable by $OWNER_USER. Fixing ownership..."
    sudo chown -R "$OWNER_USER:$OWNER_GROUP" "$LLAMA_DIR"
fi

REBUILD_REQUIRED=false

if [ -d "$LLAMA_DIR/.git" ]; then
    info "llama.cpp folder exists, checking for updates..."
    cd "$LLAMA_DIR"
    if git remote get-url origin >/dev/null 2>&1; then
        git remote set-url origin "$LLAMA_REPO_URL"
    else
        git remote add origin "$LLAMA_REPO_URL"
    fi
    BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "none")
    git pull
    AFTER=$(git rev-parse HEAD)
    if [ "$BEFORE" != "$AFTER" ]; then
        info "Updates downloaded, cleaning old build and preparing rebuild."
        rm -rf build  # Remove old build artifacts to prevent growth/conflicts
        REBUILD_REQUIRED=true
    fi
else
    if [ -n "$(find "$LLAMA_DIR" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
        fail "$LLAMA_DIR exists but is not a git repository and is not empty."
        exit 1
    fi

    info "Cloning llama.cpp from $LLAMA_REPO_URL..."
    sudo mkdir -p "$LLAMA_PARENT"
    git clone "$LLAMA_REPO_URL" "$LLAMA_DIR"
    cd "$LLAMA_DIR"
    REBUILD_REQUIRED=true
fi

# Check if binaries exist
if [ ! -f "build/bin/llama-cli" ] || [ ! -f "build/bin/llama-server" ]; then
    info "Binaries not found, build required."
    REBUILD_REQUIRED=true
fi

if [ "$REBUILD_REQUIRED" = true ]; then
    info "Building llama.cpp (CPU only)..."
    # cmake -B build: configure project and generate build files in ./build
    cmake -B build
    # --build build: compile using generated build system
    # -j$(nproc): parallelize build using all detected CPU cores
    cmake --build build -j"$(nproc)"
    ok "Build completed"
else
    ok "llama.cpp is already built and up to date"
fi

info "==> Step 5/5: Final binary output paths"
ok "Binaries are located at:"
echo "$LLAMA_DIR/build/bin/llama-server"
echo "$LLAMA_DIR/build/bin/llama-cli"
