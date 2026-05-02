#!/usr/bin/env bash
# lctl.sh v13
set -euo pipefail

BASE_URL="${LLAMA_BASE_URL:-http://127.0.0.1:8080}"
BASE_URL="${BASE_URL%/}"
TEMPERATURE="${LLAMA_TEMPERATURE:-0.7}"
LOAD_TIMEOUT="${LLAMA_LOAD_TIMEOUT:-600}"
LOAD_POLL_SECONDS="${LLAMA_LOAD_POLL_SECONDS:-5}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIASES_FILE="${LLAMA_ALIASES_FILE:-${SCRIPT_DIR}/ai/llama_aliases.ini}"

show_help() {
  cat <<EOF
Usage: $0 <command> [args]

Commands:
  health
  list
  loaded
  rawmodels
  status <model>
  load <model>
  unload <model>
  chat [model] [prompt]

Environment:
  LLAMA_BASE_URL       Default: http://127.0.0.1:8080
  LLAMA_TEMPERATURE   Default: 0.7
  LLAMA_LOAD_TIMEOUT   Default: 600
  LLAMA_LOAD_POLL_SECONDS Default: 5
  LLAMA_ALIASES_FILE  Default: ${ALIASES_FILE}

Examples:
  $0 list
  $0 loaded
  $0 status lfm25vl450
  $0 load lfm25vl450
  $0 rawmodels
  $0 chat "Say hello using the loaded model."
  $0 chat lfm25vl450 "Say hello."
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

alias_target_for_model() {
  local model="$1"

  [[ -f "$ALIASES_FILE" ]] || return 1

  awk -v key="$model" '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    {
      sub(/\r$/, "")
    }
    /^[[:space:]]*($|#)/ {
      next
    }
    {
      pos = index($0, "=")
      if (pos == 0) {
        next
      }
      alias = trim(substr($0, 1, pos - 1))
      target = trim(substr($0, pos + 1))
      if (alias == key && target != "") {
        print target
        exit
      }
    }
  ' "$ALIASES_FILE"
}

resolve_model_id() {
  local model="$1"
  local target

  target="$(alias_target_for_model "$model" || true)"
  if [[ -n "$target" ]]; then
    printf '%s\n' "$target"
  else
    printf '%s\n' "$model"
  fi
}

aliases_for_model() {
  local model="$1"

  [[ -f "$ALIASES_FILE" ]] || return 0

  awk -v target_key="$model" '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    {
      sub(/\r$/, "")
    }
    /^[[:space:]]*($|#)/ {
      next
    }
    {
      pos = index($0, "=")
      if (pos == 0) {
        next
      }
      alias = trim(substr($0, 1, pos - 1))
      target = trim(substr($0, pos + 1))
      if (target == target_key && alias != "") {
        if (found) {
          printf ","
        }
        printf "%s", alias
        found = 1
      }
    }
  ' "$ALIASES_FILE"
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

  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$json" |
      python3 -c 'import json, sys
import re

quant_re = re.compile(r"(?i)(?:^|[-_.:])((?:IQ[0-9](?:_[A-Z0-9]+)+|Q[0-9](?:_[A-Z0-9]+)+|F16|BF16))(?:\.gguf)?(?:$|[-_.:])")

def arg_value(args, name):
    for index, value in enumerate(args[:-1]):
        if value == name:
            return args[index + 1]
    return ""

def preset_value(preset, name):
    prefix = name + " = "
    for line in preset.splitlines():
        if line.startswith(prefix):
            return line[len(prefix):].strip()
    return ""

def split_repo_quant(hf_repo):
    if ":" not in hf_repo:
        return hf_repo, ""
    repo, suffix = hf_repo.rsplit(":", 1)
    if quant_re.match(suffix):
        return repo, suffix.upper()
    return hf_repo, ""

def extract_quant(*values):
    for value in values:
        if not value:
            continue
        match = quant_re.search(str(value))
        if match:
            return match.group(1).upper()
    return ""

def alias_values(aliases):
    values = []
    for alias in aliases:
        if isinstance(alias, dict):
            values.append(str(alias.get("id") or alias.get("name") or alias))
        else:
            values.append(str(alias))
    return values

payload = json.load(sys.stdin)
for item in payload.get("data", []):
    status = item.get("status") or {}
    args = status.get("args") or []
    preset = status.get("preset") or ""
    aliases = alias_values(item.get("aliases") or [])
    hf_repo = arg_value(args, "--hf-repo") or preset_value(preset, "hf-repo")
    hf_file = arg_value(args, "--hf-file") or preset_value(preset, "hf-file")
    hf_repo, repo_quant = split_repo_quant(hf_repo)
    quant = repo_quant or extract_quant(hf_file, *aliases, hf_repo)
    print(json.dumps({
        "id": item.get("id", ""),
        "status": {"value": status.get("value", "unknown")},
        "hf_repo": hf_repo,
        "hf_file": hf_file,
        "quant": quant,
        "aliases": ", ".join(aliases),
    }, separators=(",", ":")))'
    return
  fi

  printf '%s' "$json" |
    sed 's/^{"data":\[//' |
    sed 's/\],"object":"list"}$//' |
    sed 's/},{"id"/}\
{"id"/g'
}

model_id_from_object() {
  local object="$1"

  printf '%s' "$object" |
    sed -n 's/^{"id":"\([^"]*\)".*/\1/p'
}

model_status_from_object() {
  local object="$1"

  printf '%s' "$object" |
    sed -n 's/.*"status":{"value":"\([^"]*\)".*/\1/p'
}

model_field_from_object() {
  local object="$1"
  local field="$2"

  printf '%s' "$object" |
    sed -n "s/.*\"${field}\":\"\([^\"]*\)\".*/\1/p"
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
  local alias
  local status
  local quant
  local hf_repo

  json="$(get_models_json)"
  printf '%-58s %-22s %-10s %-46s %s\n' "MODEL" "ALIAS" "STATUS" "HF_REPO" "QUANT"

  while IFS= read -r object; do
    id="$(model_id_from_object "$object")"
    [[ -n "$id" ]] || continue
    alias="$(aliases_for_model "$id")"
    status="$(model_status_from_object "$object")"
    quant="$(model_field_from_object "$object" "quant")"
    hf_repo="$(model_field_from_object "$object" "hf_repo")"

    printf '%-58s %-22s %-10s %-46s %s\n' \
      "$id" \
      "${alias:--}" \
      "${status:-unknown}" \
      "${hf_repo:--}" \
      "${quant:--}"
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

  model="$(resolve_model_id "$model")"

  json="$(get_models_json)" || return 1
  object="$(model_object_from_json "$json" "$model")"
  [[ -n "$object" ]]
}

status_model() {
  local model="${1:-}"
  local requested_model
  local json
  local object
  local status
  local quant
  local hf_repo
  local hf_file

  require_model "status" "$model"
  requested_model="$model"
  model="$(resolve_model_id "$model")"

  json="$(get_models_json)"
  object="$(model_object_from_json "$json" "$model")"
  if [[ -z "$object" ]]; then
    if [[ "$requested_model" != "$model" ]]; then
      echo "alias: ${requested_model}"
    fi
    echo "${model}: missing"
    return 1
  fi

  status="$(model_status_from_object "$object")"
  quant="$(model_field_from_object "$object" "quant")"
  hf_repo="$(model_field_from_object "$object" "hf_repo")"
  hf_file="$(model_field_from_object "$object" "hf_file")"

  if [[ "$requested_model" != "$model" ]]; then
    echo "alias: ${requested_model}"
  fi
  echo "model: ${model}"
  echo "status: ${status:-unknown}"
  echo "hf_repo: ${hf_repo:--}"
  echo "quant: ${quant:--}"
  echo "hf_file: ${hf_file:--}"
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
  model="$(resolve_model_id "$model")"

  curl -sS \
    -X POST "${BASE_URL}/models/${action}" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$(json_escape "${model}")\"}"
  echo
}

load_model() {
  local model="${1:-}"
  local requested_model
  local response

  require_model "load" "$model"
  requested_model="$model"
  model="$(resolve_model_id "$model")"

  if ! response="$(curl -sS \
    -X POST "${BASE_URL}/models/load" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$(json_escape "${model}")\"}")"; then
    echo "ERROR: load request failed for ${model}" >&2
    exit 1
  fi

  if printf '%s' "$response" | grep -Fq '"success":true'; then
    if [[ "$requested_model" != "$model" ]]; then
      echo "OK: load requested for ${requested_model} -> ${model}"
    else
      echo "OK: load requested for ${model}"
    fi
  elif printf '%s' "$response" | grep -Fqi 'model is already running'; then
    if [[ "$requested_model" != "$model" ]]; then
      echo "OK: ${requested_model} -> ${model} is already running"
    else
      echo "OK: ${model} is already running"
    fi
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
  local requested_model
  local prompt="${2:-Say hello from llama-router.}"
  local response

  require_model "chat" "$model"
  requested_model="$model"
  model="$(resolve_model_id "$model")"

  if ! response="$(chat_once "$model" "$prompt")"; then
    echo "ERROR: chat request failed for ${requested_model} -> ${model}" >&2
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
  rawmodels)
    curl -sS "${BASE_URL}/models"
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
