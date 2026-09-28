#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq

input=$(cat)
tasks_file="$(jq -r '.cwd // "."' <<< "$input")/TASKS.md"
[ -f "$tasks_file" ] || exit 0
open=$(grep -E '^[[:space:]]*- \[( |~)\]' "$tasks_file")
[ -n "$open" ] || exit 0

jq -n --arg open "$open" --arg count "$(wc -l <<< "$open" | tr -d ' ')" '{hookSpecificOutput: {hookEventName: "SessionStart",
  additionalContext: ("TASKS.md in this folder has " + $count + " open items from earlier work:\n" + $open
    + "\n\nRestore them before other work: Read TASKS.md, call TaskList first so nothing is duplicated, TaskCreate each missing open item, and TaskUpdate its status to match (- [~] is in_progress). Keep TASKS.md in step as items finish, and never stage or commit it.")}}'
