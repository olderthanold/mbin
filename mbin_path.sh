#!/usr/bin/env bash
set -euo pipefail  # Stop on errors/unset vars/pipeline failures

# Purpose:
#   1) Ensure ~/mbin directory exists.
#   2) Ensure current PATH includes ~/mbin (check PATH variable, not file text).
#   3) Ensure shell prompt shows current working directory (\w or \W in PS1).
#
# Decision logic:
#   - mbin exists + PATH has mbin + prompt already shows cwd -> do nothing
#   - mbin exists + PATH missing                            -> only append PATH line
#   - mbin missing                                          -> create dir, then append PATH line if needed
#   - prompt missing cwd marker                             -> append PS1-safe block to ~/.bashrc
#
# Notes:
#   - Changes are appended to ~/.bashrc only when required.
#   - A new shell (or "source ~/.bashrc") is needed to apply appended lines.

MBIN_DIR="$HOME/mbin"  # Target tools dir
BASHRC_FILE="$HOME/.bashrc"  # User bashrc
PATH_MARKER='export PATH="$PATH:$HOME/mbin"'  # PATH line
PROMPT_MARKER="# Added by mbin_path.sh (ensure prompt shows current directory)"  # Prompt marker

# Returns success if $PATH already contains an exact $HOME/mbin path segment.
# Using ":$PATH:" avoids partial matches.
has_mbin_in_path() {
  case ":$PATH:" in
    *":$MBIN_DIR:"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Returns success if current prompt PS1 already includes cwd display marker.
# \w = full working directory, \W = basename of current directory.
prompt_shows_cwd() {
  case "${PS1:-}" in
    *"\\w"*|*"\\W"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Returns success if ~/.bashrc already contains the exact PATH export line.
path_line_exists_in_bashrc() {
  [[ -f "$BASHRC_FILE" ]] && grep -Fqx "$PATH_MARKER" "$BASHRC_FILE"
}

# Returns success if ~/.bashrc already contains our prompt block marker.
prompt_block_exists_in_bashrc() {
  [[ -f "$BASHRC_FILE" ]] && grep -Fq "$PROMPT_MARKER" "$BASHRC_FILE"
}

dir_exists=false
path_has_mbin=false
prompt_has_cwd=false
path_line_in_bashrc=false
prompt_block_in_bashrc=false

# Check current filesystem state
if [[ -d "$MBIN_DIR" ]]; then
  dir_exists=true
fi

# Check current shell environment state
if has_mbin_in_path; then
  path_has_mbin=true
fi

if prompt_shows_cwd; then
  prompt_has_cwd=true
fi

if path_line_exists_in_bashrc; then
  path_line_in_bashrc=true
fi

if prompt_block_exists_in_bashrc; then
  prompt_block_in_bashrc=true
fi

# Fully satisfied state: nothing to change
if [[ "$dir_exists" == true && "$path_has_mbin" == true && "$prompt_has_cwd" == true ]]; then
  echo "Nothing to do: mbin exists, PATH already contains it, and prompt already shows current path."
  exit 0
fi

# Create ~/mbin only when missing
if [[ "$dir_exists" == false ]]; then
  mkdir -p "$MBIN_DIR"  # Create mbin dir
  echo "Created directory: $MBIN_DIR"
fi

# Add PATH export only when current PATH is missing ~/mbin AND the line
# is not already present in ~/.bashrc. This prevents duplicates across runs
# when .bashrc was edited previously but not yet sourced in current shell.
if [[ "$path_has_mbin" == false && "$path_line_in_bashrc" == false ]]; then
  {
    echo ""
    echo "# Added by mbin_path.sh (ensure ~/mbin in PATH)"
    echo "$PATH_MARKER"
  } >> "$BASHRC_FILE"
  echo "Appended PATH update to: $BASHRC_FILE"
fi

# Add prompt configuration only when PS1 currently does not show cwd.
# The appended case block is idempotent-friendly and avoids overriding
# existing prompt formats that already include \w or \W.
if [[ "$prompt_has_cwd" == false && "$prompt_block_in_bashrc" == false ]]; then
  {
    echo ""
    echo "$PROMPT_MARKER"
    echo 'case "${PS1:-}" in'
    echo '  *"\w"*|*"\W"*) ;;'
    echo '  *) export PS1="\u@\h:\w\\$ " ;;'
    echo 'esac'
  } >> "$BASHRC_FILE"
  echo "Appended prompt update to: $BASHRC_FILE"
fi

echo "Open a new shell or run: source $BASHRC_FILE"
