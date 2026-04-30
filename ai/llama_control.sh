#!/usr/bin/env bash
# llama_control.sh v04
set -euo pipefail

BASE_URL="${LLAMA_BASE_URL:-http://127.0.0.1:8080}"
BASE_URL="${BASE_URL%/}"
TEMPERATURE="${LLAMA_TEMPERATURE:-0.7}"
LOAD_TIMEOUT="${LLAMA_LOAD_TIMEOUT:-600}"
LOAD_POLL_SECONDS="${LLAMA_LOAD_POLL_SECONDS:-5}"

show_help() {
  cat <<EOF
Usage: $0 <command> [args]

Commands:
  health
  list
  loaded
  models
  v1models
  status <model>
  load <model>
  unload <model>
  chat [model] [prompt]

Environment:
  LLAMA_BASE_URL       Default: http://127.0.0.1:8080
  LLAMA_TEMPERATURE   Default: 0.7
  LLAMA_LOAD_TIMEOUT   Default: 600
  LLAMA_LOAD_POLL_SECONDS Default: 5

Examples:
  $0 list
  $0 loaded
  $0 status lfm25vl450
  $0 load lfm25vl450
  $0 models
  $0 chat "Say hello using the loaded model."
  $0 chat lfm25vl450 "Say hello."
  LLAMA_BASE_URL=http://PUBLIC_IP:1234 $0 v1models
  LLAMA_BASE_URL=https://example.com/llama $0 chat gemma270 "Hello from phone API."
EOF
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

require_model() {
  local command_name="$1"
  local model="${2:-}"

  if [[ -z "${model}" ]]; then
    echo "ERROR: model is required for ${command_name}" >&2
    exit 1
  fi
}

get_models_json() {
  curl -sS "${BASE_URL}/models"
}

model_object_from_json() {
  local json="$1"
  local model="$2"

  model_objects_from_json "$json" |
    grep -F "\"id\":\"${model}\"" |
    head -n 1 || true
}

model_objects_from_json() {
  local json="$1"

  printf '%s' "$json" |
    sed 's/},{"id"/}\
{"id"/g'
}

model_id_from_object() {
  local object="$1"

  printf '%s' "$object" |
    sed -n 's/.*"id":"\([^"]*\)".*/\1/p'
}

model_status_from_object() {
  local object="$1"

  printf '%s' "$object" |
    sed -n 's/.*"status":{"value":"\([^"]*\)".*/\1/p'
}

get_model_status() {
  local model="$1"
  local json
  local object
  local status

  if ! json="$(get_models_json)"; then
    echo "api_error"
    return 1
  fi

  object="$(model_object_from_json "$json" "$model")"
  if [[ -z "$object" ]]; then
    echo "missing"
    return 1
  fi

  status="$(model_status_from_object "$object")"
  if [[ -z "$status" ]]; then
    echo "unknown"
    return 1
  fi

  echo "$status"
}

list_models() {
  local json
  local object
  local id
  local status

  json="$(get_models_json)"
  printf '%-12s %s\n' "MODEL" "STATUS"

  while IFS= read -r object; do
    id="$(model_id_from_object "$object")"
    status="$(model_status_from_object "$object")"
    [[ -n "$id" ]] || continue
    printf '%-12s %s\n' "$id" "${status:-unknown}"
  done < <(model_objects_from_json "$json")
}

is_ready_status() {
  case "$1" in
    loaded|running|ready)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

loaded_models() {
  local found="false"

  while IFS= read -r id; do
    echo "$id"
    found="true"
  done < <(ready_model_ids)

  if [[ "$found" != "true" ]]; then
    echo "none"
  fi
}

ready_model_ids() {
  local json
  local object
  local id
  local status

  json="$(get_models_json)"

  while IFS= read -r object; do
    id="$(model_id_from_object "$object")"
    status="$(model_status_from_object "$object")"
    [[ -n "$id" ]] || continue

    if is_ready_status "$status"; then
      echo "$id"
    fi
  done < <(model_objects_from_json "$json")
}

single_loaded_model() {
  local id
  local first=""
  local count=0

  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    count=$((count + 1))
    if [[ -z "$first" ]]; then
      first="$id"
    fi
  done < <(ready_model_ids)

  if (( count == 1 )); then
    echo "$first"
    return 0
  fi

  if (( count == 0 )); then
    echo "ERROR: no loaded model found. Run: $0 load <model>" >&2
  else
    echo "ERROR: multiple loaded models found; pass model explicitly: $0 chat <model> <prompt>" >&2
    ready_model_ids >&2
  fi

  exit 1
}

is_known_model() {
  local model="$1"
  local json
  local object

  json="$(get_models_json)" || return 1
  object="$(model_object_from_json "$json" "$model")"
  [[ -n "$object" ]]
}

status_model() {
  local model="${1:-}"
  local status

  require_model "status" "$model"

  status="$(get_model_status "$model" || true)"
  echo "${model}: ${status:-unknown}"
}

wait_for_model_ready() {
  local model="$1"
  local elapsed=0
  local status=""

  while (( elapsed <= LOAD_TIMEOUT )); do
    status="$(get_model_status "$model" || true)"

    if is_ready_status "$status"; then
      echo "OK: ${model} is ready (status: ${status})"
      return 0
    fi

    echo "Waiting for ${model}: status=${status:-unknown}, elapsed=${elapsed}s/${LOAD_TIMEOUT}s"
    sleep "$LOAD_POLL_SECONDS"
    elapsed=$((elapsed + LOAD_POLL_SECONDS))
  done

  echo "ERROR: timed out waiting for ${model} to become ready (last status: ${status:-unknown})" >&2
  echo "Hint: sudo journalctl -u llama-router.service -n 120 --no-pager" >&2
  exit 1
}

post_model_action() {
  local action="$1"
  local model="${2:-}"

  require_model "${action}" "${model}"

  curl -sS \
    -X POST "${BASE_URL}/models/${action}" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$(json_escape "${model}")\"}"
  echo
}

load_model() {
  local model="${1:-}"
  local response

  require_model "load" "$model"

  if ! response="$(curl -sS \
    -X POST "${BASE_URL}/models/load" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$(json_escape "${model}")\"}")"; then
    echo "ERROR: load request failed for ${model}" >&2
    exit 1
  fi

  if printf '%s' "$response" | grep -Fq '"success":true'; then
    echo "OK: load requested for ${model}"
  elif printf '%s' "$response" | grep -Fqi 'model is already running'; then
    echo "OK: ${model} is already running"
  else
    echo "$response" >&2
    exit 1
  fi

  wait_for_model_ready "$model"
}

chat_once() {
  local model="$1"
  local prompt="$2"
  local escaped_model
  local escaped_prompt

  escaped_model="$(json_escape "${model}")"
  escaped_prompt="$(json_escape "${prompt}")"

  curl -sS \
    -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${escaped_model}\",\"messages\":[{\"role\":\"user\",\"content\":\"${escaped_prompt}\"}],\"temperature\":${TEMPERATURE}}"
}

chat() {
  local model="${1:-}"
  local prompt="${2:-Say hello from llama-router.}"
  local response

  require_model "chat" "$model"

  if ! response="$(chat_once "$model" "$prompt")"; then
    echo "ERROR: chat request failed for ${model}" >&2
    exit 1
  fi

  if printf '%s' "$response" | grep -Fq 'proxy error: Could not establish connection'; then
    echo "WARN: model backend is not reachable yet; retrying once in 5s..." >&2
    sleep 5

    if ! response="$(chat_once "$model" "$prompt")"; then
      echo "ERROR: chat retry failed for ${model}" >&2
      exit 1
    fi

    if printf '%s' "$response" | grep -Fq 'proxy error: Could not establish connection'; then
      echo "$response"
      echo "Hint: sudo journalctl -u llama-router.service -n 120 --no-pager" >&2
      exit 1
    fi
  fi

  echo "$response"
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
  list)
    list_models
    ;;
  loaded)
    loaded_models
    ;;
  models)
    curl -sS "${BASE_URL}/models"
    echo
    ;;
  v1models)
    curl -sS "${BASE_URL}/v1/models"
    echo
    ;;
  status)
    status_model "${2:-}"
    ;;
  load)
    load_model "${2:-}"
    ;;
  unload)
    post_model_action "unload" "${2:-}"
    ;;
  chat)
    if [[ "$#" -eq 1 ]]; then
      model="$(single_loaded_model)"
      prompt="Say hello from llama-router."
    elif [[ "$#" -eq 2 ]]; then
      if is_known_model "${2:-}"; then
        model="${2:-}"
        prompt="Say hello from llama-router."
      else
        model="$(single_loaded_model)"
        prompt="${2:-}"
      fi
    else
      model="${2:-}"
      shift 2
      prompt="$*"
    fi
    chat "${model}" "${prompt}"
    ;;
  *)
    echo "ERROR: unknown command: ${command}" >&2
    show_help >&2
    exit 1
    ;;
esac
