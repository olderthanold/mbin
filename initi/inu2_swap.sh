#!/usr/bin/env bash
set -euo pipefail

# Compatibility wrapper:
# renamed entry point is inu2_swap.sh.
# canonical script is ini2sys_swap.sh.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/ini2sys_swap.sh" "$@"
