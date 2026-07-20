#!/usr/bin/env bash
# Runs llama-cli with the preset quantized Gemma 3 1B model for local interactive use.
# rgemma_1b.sh v01
set -euo pipefail

LLAMA_CLI="${LLAMA_CLI:-/m/llama.cpp/build/bin/llama-cli}"
"$LLAMA_CLI" -hf unsloth/gemma-3-1b-it-GGUF:Q3_K_S --reasoning off --temp 0.7 --no-mmproj
