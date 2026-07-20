#!/usr/bin/env bash
# Compatibility entry point for swap setup; forwards all arguments unchanged to ini2sys_swap.sh.
set -euo pipefail

# Compatibility wrapper:
# entry point name: ini2sys_swap_wrapper.sh
# canonical script is ini2sys_swap.sh.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/ini2sys_swap.sh" "$@"
