#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures.

# Purpose:
#   1) Ensure ~/mbin exists.
#   2) Ensure PATH includes ~/mbin.
#   3) Ensure prompt shows full cwd (\w), not only basename (\W).

MBIN_DIR="$HOME/mbin"
BASHRC_FILE="$HOME/.bashrc"
PATH_MARKER='export PATH="$PATH:$HOME/mbin"'
PROMPT_MARKER="# Added by mbin_path.sh (ensure prompt shows full current directory)"

has_mbin_in_path() {
  case ":$PATH:" in
    *":$MBIN_DIR:"*) return 0 ;;
    *) return 1 ;;
  esac
}

prompt_shows_full_cwd_now() {
  case "${PS1:-}" in
    *"\\w"*) return 0 ;;
    *) return 1 ;;
  esac
}

path_line_exists_in_bashrc() {
  [[ -f "$BASHRC_FILE" ]] && grep -Fqx "$PATH_MARKER" "$BASHRC_FILE"
}

prompt_block_exists_in_bashrc() {
  [[ -f "$BASHRC_FILE" ]] && grep -Fq "$PROMPT_MARKER" "$BASHRC_FILE"
}

if [[ ! -d "$MBIN_DIR" ]]; then
  mkdir -p "$MBIN_DIR"
  echo "Created directory: $MBIN_DIR"
fi

if ! has_mbin_in_path && ! path_line_exists_in_bashrc; then
  {
    echo ""
    echo "# Added by mbin_path.sh (ensure ~/mbin in PATH)"
    echo "$PATH_MARKER"
  } >> "$BASHRC_FILE"
  echo "Appended PATH update to: $BASHRC_FILE"
fi

if ! prompt_shows_full_cwd_now && ! prompt_block_exists_in_bashrc; then
  {
    echo ""
    echo "$PROMPT_MARKER"
    echo 'case "${PS1:-}" in'
    echo '  *"\w"*) ;;'
    echo '  *"\W"*) export PS1="${PS1//\W/\w}" ;;'
    echo '  *) export PS1="\u@\h:\w\\$ " ;;'
    echo 'esac'
  } >> "$BASHRC_FILE"
  echo "Appended prompt update to: $BASHRC_FILE"
fi

echo "Open a new shell or run: source $BASHRC_FILE"
