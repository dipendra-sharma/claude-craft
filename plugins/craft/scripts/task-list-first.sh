#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq

files_that_need_a_list=3

input=$(cat)
[ -z "$(jq -r '.agent_id // empty' <<< "$input")" ] || exit 0
cwd=$(jq -r '.cwd // empty' <<< "$input")
path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<< "$input")
inside_project "$path" "$cwd" || exit 0
session=$(jq -r '.session_id // "none"' <<< "$input")
[ "$(open_tasks "$session" | jq 'length')" = 0 ] || exit 0
transcript=$(jq -r '.transcript_path // empty' <<< "$input")
[ -f "$transcript" ] || exit 0

turn=$(current_turn "$transcript")
files=$(jq -r --arg cwd "$cwd" --arg path "$path" --argjson needed "$files_that_need_a_list" '
  [.blocks[] | select(.type == "tool_use")] as $tools
  | if any($tools[]; .name | test("^(TaskCreate|TaskUpdate|TodoWrite)$")) then empty
    else [$tools[] | select(.name | test("^(Edit|Write|MultiEdit|NotebookEdit)$"))
          | .input.file_path // .input.notebook_path // "" | select(startswith($cwd + "/"))] + [$path]
         | unique | select(length >= $needed) | .[]
    end' <<< "$turn")
[ -n "$files" ] || exit 0

asked="${TMPDIR:-/tmp}/claude-craft-tasks-$session"
prompt=$(jq -r '.prompt' <<< "$turn")
[ "$(cat "$asked" 2>/dev/null)" = "$prompt" ] && exit 0
printf '%s' "$prompt" > "$asked"

printf 'This work now touches %s files and has no todo list:\n%s\n\nCreate the list before the next edit: one TaskCreate per step. If TaskCreate, TaskUpdate, TaskList and TaskGet show only as deferred names, load them first with ToolSearch "select:TaskCreate,TaskUpdate,TaskList,TaskGet". Mark an item in_progress before you start it and completed only when its check passes. Then retry the edit.\n' \
  "$(wc -l <<< "$files" | tr -d ' ')" "$files" >&2
exit 2
