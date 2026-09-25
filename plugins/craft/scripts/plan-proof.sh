#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq

input=$(cat)
[ -z "$(jq -r '.agent_id // empty' <<< "$input")" ] || exit 0
path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<< "$input")
inside_project "$path" "$(jq -r '.cwd // empty' <<< "$input")" || exit 0
transcript=$(jq -r '.transcript_path // empty' <<< "$input")
[ -f "$transcript" ] || exit 0

turn=$(current_turn "$transcript")
jq -e '.blocks | any(.type == "text" and (.text | test("done when:"; "i")))' <<< "$turn" >/dev/null && exit 0

asked="${TMPDIR:-/tmp}/claude-craft-plan-$(jq -r '.session_id // "none"' <<< "$input")"
prompt=$(jq -r '.prompt' <<< "$turn")
[ "$(cat "$asked" 2>/dev/null)" = "$prompt" ] && exit 0
printf '%s' "$prompt" > "$asked"

printf 'Plan the proof of work before the first edit. Write one line in your reply:\n\n  Done when: <the observable result> — checked by: <the exact command or read-back>\n\nThen retry the edit. Run that same check before you call the work done.\n' >&2
exit 2
