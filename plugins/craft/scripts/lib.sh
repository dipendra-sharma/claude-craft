#!/bin/bash

craft_rules_off() { [ "${CLAUDE_CRAFT_RULES:-on}" = "off" ]; }

require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  printf 'craft: jq is not installed, so the craft hooks are not running. Install it: brew install jq\n' >&2
  exit 1
}

craft_allow_file() { printf '%s' "${CLAUDE_CRAFT_ALLOW_FILE:-/tmp/claude-craft-allow-$(id -u)}"; }

inside_project() {
  case "$1" in "$2"/*) return 0 ;; esac
  return 1
}

current_turn() {
  jq -sc '
    def is_prompt: .type == "user" and (.isMeta | not)
      and (.message.content | if type == "string" then true
           else any(.[]; .type == "text") and all(.[]; .type != "tool_result") end);
    ([to_entries[] | select(.value | is_prompt) | .key] | last) as $start
    | { prompt: (if $start == null then "" else .[$start].uuid end),
        blocks: [.[(($start // -1) + 1):][] | select(.type == "assistant") | .message.content[]?] }
  ' "$1"
}

tasks_dir() { printf '%s/%s' "${CLAUDE_CRAFT_TASKS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tasks}" "$1"; }

open_tasks() {
  local dir
  dir=$(tasks_dir "$1")
  if [[ ! "$1" =~ ^[A-Za-z0-9_-]+$ ]] || ! compgen -G "$dir/*.json" >/dev/null; then
    printf '[]'
    return
  fi
  jq -s '[.[] | select(.status == "pending" or .status == "in_progress")] | sort_by(.id | tonumber? // 0)' "$dir"/*.json 2>/dev/null \
    || printf '[]'
}
