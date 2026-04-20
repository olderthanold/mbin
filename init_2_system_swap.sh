#!/usr/bin/env bash
set -euo pipefail

# Compatibility wrapper:
# original entry name kept for callers that still use init_2_system_swap.sh.
# canonical script is ini2sys_swap.sh.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/ini2sys_swap.sh" "$@"
