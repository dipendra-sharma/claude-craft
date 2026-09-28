#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq

input=$(cat)
[ "$(jq -r '.stop_hook_active // false' <<< "$input")" = true ] && exit 0
session=$(jq -r '.session_id // "none"' <<< "$input")
tasks_file="$(jq -r '.cwd // "."' <<< "$input")/TASKS.md"

open=$(open_tasks "$session")
unfinished=$(jq -r '.[] | select((.description // "") | test("(^|\\n)[[:space:]]*blocked:"; "i") | not) | "#\(.id) [\(.status)] \(.subject)"' <<< "$open")

stale=""
if [ -f "$tasks_file" ] && [ -n "$(find "$(tasks_dir "$session")" -name '*.json' -newer "$tasks_file" 2>/dev/null)" ]; then
  stale="TASKS.md is older than the todo list. Re-save it: TaskList, then Write one line per item as - [ ] / - [~] / - [x] + subject + one-line note."
fi

[ -n "$unfinished" ] || [ -n "$stale" ] || exit 0

reason=""
if [ -n "$unfinished" ]; then
  reason="These todo items are still open:
$unfinished

Pick the next one and keep going; do not write a summary while items are open. If one is truly blocked, leave it open and add a line to its description with TaskUpdate: Blocked: <the reason>."
  if [ ! -f "$tasks_file" ]; then
    reason+="
If this work may run past a context summary or into another session, mirror the list to TASKS.md in the working folder."
  fi
fi
[ -n "$stale" ] && reason+="${reason:+

}$stale"

jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
