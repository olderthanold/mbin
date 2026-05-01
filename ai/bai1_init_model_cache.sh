#!/usr/bin/env bash
# bai1_init_model_cache.sh v01
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MODELS_PRESET="${LLAMA_MODELS_PRESET:-${SCRIPT_DIR}/llama_models.ini}"
LLAMA_CONTROL_SCRIPT="${LLAMA_CONTROL_SCRIPT:-${SCRIPT_DIR}/llama_control.sh}"
SERVICE_NAME="${SERVICE_NAME:-llama-router}"
SETTINGS_ENV_FILE="${SETTINGS_ENV_FILE:-/etc/default/${SERVICE_NAME}}"
BASE_URL="${LLAMA_BASE_URL:-http://127.0.0.1:8080}"
LOAD_TIMEOUT="${LLAMA_LOAD_TIMEOUT:-1200}"
CHECK_ONLY="false"

if [[ -f "$SETTINGS_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a
  . "$SETTINGS_ENV_FILE"
  set +a
fi

HF_CACHE_DIR="${HF_CACHE_DIR:-${HF_HOME:-/m/hfcache}}"
HUGGINGFACE_HUB_CACHE="${HUGGINGFACE_HUB_CACHE:-${HF_HUB_CACHE:-${HF_CACHE_DIR}/hub}}"

show_help() {
  cat <<EOF
Usage: $0 [--check-only]

Checks configured llama router models and downloads missing GGUF files by
loading models one by one through llama-router.

Environment:
  LLAMA_BASE_URL       Default: $BASE_URL
  LLAMA_LOAD_TIMEOUT   Default: $LOAD_TIMEOUT
  LLAMA_MODELS_PRESET  Default: $MODELS_PRESET
  HF_CACHE_DIR         Default: $HF_CACHE_DIR
EOF
}

fail() {
  echo -e "${RED}ERROR: $*${NC}" >&2
  exit 1
}

info() {
  echo -e "${YELLOW}$*${NC}"
}

ok() {
  echo -e "${GREEN}$*${NC}"
}

warn() {
  echo -e "${YELLOW}WARN: $*${NC}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only)
      CHECK_ONLY="true"
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

[[ -f "$MODELS_PRESET" ]] || fail "models preset not found: $MODELS_PRESET"
[[ -f "$LLAMA_CONTROL_SCRIPT" ]] || fail "llama control script not found: $LLAMA_CONTROL_SCRIPT"

require_router() {
  if ! command -v curl >/dev/null 2>&1; then
    fail "curl not found"
  fi

  curl -fsS --max-time 10 "${BASE_URL}/health" >/dev/null ||
    fail "llama router is not reachable at ${BASE_URL}; run 0buildai.sh --service-only first"
}

model_entries_from_preset() {
  awk '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    function emit() {
      if (section != "" && section != "*" && repo != "") {
        print section "|" repo "|" file
      }
    }
    {
      sub(/\r$/, "")
    }
    /^\[/ {
      emit()
      section = $0
      sub(/^\[/, "", section)
      sub(/\]$/, "", section)
      repo = ""
      file = ""
      next
    }
    /^[[:space:]]*hf-repo[[:space:]]*=/ {
      sub(/^[^=]*=/, "")
      repo = trim($0)
      next
    }
    /^[[:space:]]*hf-file[[:space:]]*=/ {
      sub(/^[^=]*=/, "")
      file = trim($0)
      next
    }
    END {
      emit()
    }
  ' "$MODELS_PRESET"
}

normalize_quant() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

is_quant_suffix() {
  [[ "$1" =~ ^(IQ[0-9](_[A-Za-z0-9]+)+|Q[0-9](_[A-Za-z0-9]+)+|F16|BF16)$ ]]
}

extract_quant_from_text() {
  printf '%s\n' "$1" |
    grep -Eio '(IQ[0-9](_[A-Za-z0-9]+)+|Q[0-9](_[A-Za-z0-9]+)+|F16|BF16)' |
    head -n 1 |
    tr '[:lower:]' '[:upper:]' || true
}

split_repo_and_quant() {
  local raw_repo="$1"
  local repo="$raw_repo"
  local quant=""
  local suffix

  if [[ "$raw_repo" == *:* ]]; then
    suffix="${raw_repo##*:}"
    if is_quant_suffix "$suffix"; then
      repo="${raw_repo%:*}"
      quant="$(normalize_quant "$suffix")"
    fi
  fi

  printf '%s|%s\n' "$repo" "$quant"
}

repo_cache_path() {
  local repo="$1"
  local owner
  local name

  [[ "$repo" == */* ]] || return 1
  owner="${repo%%/*}"
  name="${repo#*/}"
  printf '%s/models--%s--%s\n' "$HUGGINGFACE_HUB_CACHE" "$owner" "$name"
}

find_cached_gguf() {
  local repo="$1"
  local hf_file="$2"
  local quant="$3"
  local cache_path

  cache_path="$(repo_cache_path "$repo")" || return 1
  [[ -d "$cache_path" ]] || return 1

  if [[ -n "$hf_file" ]]; then
    find -L "$cache_path" -type f -name "$hf_file" -size +1M -print -quit 2>/dev/null
    return 0
  fi

  if [[ -n "$quant" ]]; then
    find -L "$cache_path" -type f -iname "*${quant}*.gguf" -size +1M -print -quit 2>/dev/null
    return 0
  fi

  find -L "$cache_path" -type f -iname "*.gguf" -size +1M -print -quit 2>/dev/null
}

human_size() {
  local file_path="$1"
  local bytes

  bytes="$(stat -c '%s' "$file_path" 2>/dev/null || true)"
  if [[ -z "$bytes" ]]; then
    printf '%s\n' "-"
  elif command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --suffix=B "$bytes"
  else
    printf '%sB\n' "$bytes"
  fi
}

print_cache_line() {
  local model="$1"
  local cache_state="$2"
  local size="$3"
  local match="$4"

  printf '%-20s %-8s %-8s %s\n' "$model" "$cache_state" "$size" "${match:-"-"}"
}

download_model() {
  local model="$1"

  info "Downloading missing model via router load: $model"
  LLAMA_BASE_URL="$BASE_URL" LLAMA_LOAD_TIMEOUT="$LOAD_TIMEOUT" bash "$LLAMA_CONTROL_SCRIPT" load "$model"
  LLAMA_BASE_URL="$BASE_URL" bash "$LLAMA_CONTROL_SCRIPT" unload "$model" >/dev/null 2>&1 || true
}

info "Running bai1_init_model_cache.sh v01"
echo "Models preset: $MODELS_PRESET"
echo "HF cache: $HF_CACHE_DIR"
echo "HF hub cache: $HUGGINGFACE_HUB_CACHE"
echo "Router URL: $BASE_URL"

require_router

missing_count=0
downloaded_count=0

printf '%-20s %-8s %-8s %s\n' "MODEL" "CACHE" "SIZE" "MATCH"

while IFS='|' read -r model raw_repo hf_file; do
  [[ -n "$model" ]] || continue

  split_result="$(split_repo_and_quant "$raw_repo")"
  repo="${split_result%%|*}"
  quant="${split_result#*|}"
  if [[ -z "$quant" ]]; then
    quant="$(extract_quant_from_text "$hf_file")"
  fi

  match_path="$(find_cached_gguf "$repo" "$hf_file" "$quant" | head -n 1 || true)"
  if [[ -n "$match_path" ]]; then
    print_cache_line "$model" "yes" "$(human_size "$match_path")" "$match_path"
    continue
  fi

  missing_count=$((missing_count + 1))
  print_cache_line "$model" "no" "-" "${hf_file:-${repo}:${quant:-any}}"

  if [[ "$CHECK_ONLY" == "true" ]]; then
    continue
  fi

  download_model "$model"
  downloaded_count=$((downloaded_count + 1))

  match_path="$(find_cached_gguf "$repo" "$hf_file" "$quant" | head -n 1 || true)"
  if [[ -n "$match_path" ]]; then
    print_cache_line "$model" "yes" "$(human_size "$match_path")" "$match_path"
  else
    fail "model loaded but GGUF was not found in cache for: $model"
  fi
done < <(model_entries_from_preset)

if [[ "$CHECK_ONLY" == "true" && "$missing_count" -gt 0 ]]; then
  warn "Missing GGUF model(s): $missing_count"
  exit 1
fi

if [[ "$missing_count" -eq 0 ]]; then
  ok "All configured GGUF models are already present."
else
  ok "Downloaded missing GGUF model(s): $downloaded_count"
fi
