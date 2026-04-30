#!/usr/bin/env bash
# bai1_build_llama.sh v06
set -euo pipefail

# Ensure local bin is in PATH (where uv and other user-local tools are installed).
export PATH="$HOME/.local/bin:$PATH"

LLAMA_DIR="${LLAMA_DIR:-/m/llama.cpp}"
LLAMA_PARENT="$(dirname "$LLAMA_DIR")"
LLAMA_REPO_URL="${LLAMA_REPO_URL:-https://github.com/ggml-org/llama.cpp}"
OWNER_USER="${SUDO_USER:-${USER:-$(whoami)}}"
OWNER_GROUP="$(id -gn "$OWNER_USER" 2>/dev/null || echo "$OWNER_USER")"
FORCE="false"

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
    echo -e "${RED}ERROR: $*${NC}" >&2
    exit 1
}

show_help() {
    cat <<EOF
Usage: $0 [--force]

Build or verify llama.cpp.

Defaults:
  LLAMA_DIR=$LLAMA_DIR
  LLAMA_REPO_URL=$LLAMA_REPO_URL

Options:
  --force     Pull/update and rebuild even when an existing build is present.
  -h, --help  Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE="true"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            fail "unknown argument: $1"
            ;;
    esac
done

run_as_owner() {
    if [[ "$EUID" -eq 0 && "$OWNER_USER" != "root" ]]; then
        sudo -u "$OWNER_USER" "$@"
    else
        "$@"
    fi
}

smoke_binary() {
    local binary_path="$1"

    if [[ ! -x "$binary_path" ]]; then
        fail "required binary is missing or not executable: $binary_path"
    fi

    if run_as_owner "$binary_path" --version >/dev/null 2>&1; then
        ok "Smoke test passed: $binary_path --version"
        return 0
    fi

    if run_as_owner "$binary_path" --help >/dev/null 2>&1; then
        ok "Smoke test passed: $binary_path --help"
        return 0
    fi

    fail "binary exists but cannot run: $binary_path
Run a full reset/rebuild with: sudo bash /m/mbin/0buildai.sh --force"
}

verify_existing_build() {
    info "Verifying existing llama.cpp build without update/rebuild..."
    smoke_binary "$LLAMA_DIR/build/bin/llama-server"
    smoke_binary "$LLAMA_DIR/build/bin/llama-cli"
    ok "Existing llama.cpp build is usable"
}

validate_destructive_llama_dir() {
    case "$LLAMA_DIR" in
        ""|"/"|"."|".."|"/m"|"/m/"|"/home"|"/home/"|"/root"|"/root/"|"/usr"|"/usr/"|"/opt"|"/opt/"|"/var"|"/var/")
            fail "refusing destructive operation for unsafe LLAMA_DIR: ${LLAMA_DIR:-<empty>}"
            ;;
    esac
}

cleanup_non_git_llama_dir() {
    if [[ ! -d "$LLAMA_DIR" ]]; then
        return 0
    fi

    if [[ -d "$LLAMA_DIR/.git" ]]; then
        return 0
    fi

    validate_destructive_llama_dir
    info "$LLAMA_DIR exists but is not a git repository. Removing disposable build target..."
    sudo rm -rf "$LLAMA_DIR"
    ok "Removed non-git LLAMA_DIR: $LLAMA_DIR"
}

install_dependencies() {
    info "==> Step 1/5: Updating apt package index..."
    sudo apt-get update

    info "==> Step 2/5: Installing dependencies (git, build-essential, cmake, python3, curl, libssl-dev)..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
      git \
      build-essential \
      cmake \
      python3 \
      curl \
      libssl-dev

    info "==> Step 3/5: Ensuring uv is installed..."
    if ! command -v uv >/dev/null 2>&1; then
        info "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
    else
        ok "uv is already installed."
    fi

    uv --version
}

prepare_target_directory() {
    info "==> Step 4/5: Preparing llama.cpp source directory..."

    if [[ -d "$LLAMA_DIR" ]]; then
        ok "$LLAMA_DIR already exists."
    else
        info "$LLAMA_DIR not found. Creating parent directory..."
        sudo mkdir -p "$LLAMA_PARENT"
    fi

    if [[ -d "$LLAMA_DIR" && ! -w "$LLAMA_DIR" ]]; then
        info "$LLAMA_DIR is not writable by $OWNER_USER. Fixing ownership..."
        sudo chown -R "$OWNER_USER:$OWNER_GROUP" "$LLAMA_DIR"
    fi
}

clone_or_update_source() {
    if [[ -d "$LLAMA_DIR/.git" ]]; then
        info "Updating existing llama.cpp repo..."
        cd "$LLAMA_DIR"
        if git remote get-url origin >/dev/null 2>&1; then
            git remote set-url origin "$LLAMA_REPO_URL"
        else
            git remote add origin "$LLAMA_REPO_URL"
        fi
        git pull
        info "Cleaning old build directory for forced rebuild..."
        rm -rf build
        return 0
    fi

    info "Cloning llama.cpp from $LLAMA_REPO_URL..."
    git clone "$LLAMA_REPO_URL" "$LLAMA_DIR"
    cd "$LLAMA_DIR"
}

build_source() {
    info "Building llama.cpp (CPU only)..."
    cmake -B build
    cmake --build build -j"$(nproc)"
    ok "Build completed"
}

normalize_target_ownership() {
    if [[ -d "$LLAMA_DIR" ]]; then
        info "Normalizing llama.cpp ownership to $OWNER_USER:$OWNER_GROUP..."
        sudo chown -R "$OWNER_USER:$OWNER_GROUP" "$LLAMA_DIR"
    fi
}

info "Running bai1_build_llama.sh v06"

if [[ -d "$LLAMA_DIR/.git" && "$FORCE" != "true" ]]; then
    verify_existing_build
else
    if [[ -d "$LLAMA_DIR/.git" && "$FORCE" == "true" ]]; then
        info "Force mode enabled: existing repo will be updated and rebuilt."
    fi

    cleanup_non_git_llama_dir
    install_dependencies
    prepare_target_directory
    clone_or_update_source
    build_source
    normalize_target_ownership
    verify_existing_build
fi

info "==> Step 5/5: Final binary output paths"
ok "Binaries are located at:"
echo "$LLAMA_DIR/build/bin/llama-server"
echo "$LLAMA_DIR/build/bin/llama-cli"
