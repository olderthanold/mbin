#!/usr/bin/env bash
# llama_control.sh v01
set -euo pipefail

BASE_URL="${LLAMA_BASE_URL:-http://127.0.0.1:8080}"
BASE_URL="${BASE_URL%/}"
TEMPERATURE="${LLAMA_TEMPERATURE:-0.7}"

show_help() {
  cat <<EOF
Usage: $0 <command> [args]

Commands:
  health
  models
  v1models
  load <model>
  unload <model>
  chat <model> [prompt]

Environment:
  LLAMA_BASE_URL       Default: http://127.0.0.1:8080
  LLAMA_TEMPERATURE   Default: 0.7

Examples:
  $0 models
  $0 load lfm25vl450
  $0 chat lfm25vl450 "Say hello."
  LLAMA_BASE_URL=http://PUBLIC_IP:1234 $0 v1models
  LLAMA_BASE_URL=https://example.com/llama $0 chat gemma270 "Hello from phone API."
EOF
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

post_model_action() {
  local action="$1"
  local model="${2:-}"

  if [[ -z "${model}" ]]; then
    echo "ERROR: model is required for ${action}" >&2
    exit 1
  fi

  curl -sS \
    -X POST "${BASE_URL}/models/${action}" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$(json_escape "${model}")\"}"
  echo
}

chat() {
  local model="${1:-}"
  local prompt="${2:-Say hello from llama-router.}"

  if [[ -z "${model}" ]]; then
    echo "ERROR: model is required for chat" >&2
    exit 1
  fi

  local escaped_model
  local escaped_prompt
  escaped_model="$(json_escape "${model}")"
  escaped_prompt="$(json_escape "${prompt}")"

  curl -sS \
    -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${escaped_model}\",\"messages\":[{\"role\":\"user\",\"content\":\"${escaped_prompt}\"}],\"temperature\":${TEMPERATURE}}"
  echo
}

command="${1:-}"
case "${command}" in
  -h|--help|"")
    show_help
    ;;
  health)
    curl -sS "${BASE_URL}/health"
    echo
    ;;
  models)
    curl -sS "${BASE_URL}/models"
    echo
    ;;
  v1models)
    curl -sS "${BASE_URL}/v1/models"
    echo
    ;;
  load)
    post_model_action "load" "${2:-}"
    ;;
  unload)
    post_model_action "unload" "${2:-}"
    ;;
  chat)
    model="${2:-}"
    if [[ "$#" -gt 2 ]]; then
      shift 2
      prompt="$*"
    else
      prompt="Say hello from llama-router."
    fi
    chat "${model}" "${prompt}"
    ;;
  *)
    echo "ERROR: unknown command: ${command}" >&2
    show_help >&2
    exit 1
    ;;
esac
