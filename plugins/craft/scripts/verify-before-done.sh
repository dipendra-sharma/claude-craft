#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq

input=$(cat)
[ "$(jq -r '.stop_hook_active // false' <<< "$input")" = true ] && exit 0
transcript=$(jq -r '.transcript_path // empty' <<< "$input")
[ -f "$transcript" ] || exit 0
last_message=$(jq -r '.last_assistant_message // ""' <<< "$input")
grep -qiE 'unverified|not verified' <<< "$last_message" && exit 0

check_pattern='(^|[^a-z])(test|tests|spec|lint|check|build|analy[sz]e|vet|clippy|tsc|typecheck|pytest|jest|vitest|rspec|xcodebuild|gradlew|mvn|make|ruff|eslint|biome|shellcheck|mypy|pyright|validate|verify)([^a-z]|$)'
turn=$(current_turn "$transcript")

unchecked=$(jq -r --arg checks "$check_pattern" --arg cwd "$(jq -r '.cwd // ""' <<< "$input")" '
  [.blocks[] | select(.type == "tool_use")] | to_entries as $tools
  | [$tools[] | select(.value.name == "Bash") | {key, command: (.value.input.command // "")}] as $runs
  | [$tools[]
     | select(.value.name | test("^(Edit|Write|MultiEdit|NotebookEdit)$"))
     | {key, file: (.value.input.file_path // .value.input.notebook_path // "")}
     | select((.file | startswith($cwd + "/")) and (.file | test("\\.(md|mdx|txt|rst)$"; "i") | not))
     | . as $edit
     | select([$runs[] | select(.key > $edit.key
         and ((.command | test($checks; "i")) or (.command | contains($edit.file | split("/") | last))))] | length == 0)
     | .file]
  | unique | .[]' <<< "$turn")
[ -n "$unchecked" ] || exit 0

plan=$( { jq -r '.blocks[] | select(.type == "text") | .text' <<< "$turn"; printf '%s\n' "$last_message"; } | grep -iE -m1 'done when:')
if [ -n "$plan" ]; then next="Your plan said:
$plan
Run that check now."
else next="Run the cheapest check that could fail: one test, a build, a lint, or running the changed script."
fi

jq -n --arg files "$unchecked" --arg next "$next" '{decision: "block", reason: ("These files changed after the last check ran:\n" + $files + "\n\n" + $next + "\nIf it cannot be checked here, say plainly that the change is unverified and why.")}'
