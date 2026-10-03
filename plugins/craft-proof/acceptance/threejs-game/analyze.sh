#!/bin/bash
set -u
results=${1:?usage: analyze-complex.sh <aggregate-result.json>}
hidden="$(cd "$(dirname "$0")" && pwd)/run.sh"

jq -r '.cases[] | .name as $n | (.arms | to_entries[]) | .key as $arm | .value | to_entries[] | [$arm, (.key + 1), .value.tracePath, .value.score, .value.costUsd, .value.turns, .value.durationSeconds, (.value.error // "-")] | @tsv' "$results" |
while IFS=$'\t' read -r arm run trace score cost turns seconds error; do
  base=$(dirname "$(dirname "$trace")")
  chmod 700 "$base" "$base/sealed" 2>/dev/null
  workspace="$base/sealed/home/cwd"
  report=$(/bin/bash "$hidden" "$workspace" | sed 's/\x1b\[[0-9;]*m//g')
  hidden_pass=$(printf '%s\n' "$report" | /usr/bin/grep -Eo 'pass [0-9]+' | head -1 | cut -d' ' -f2)
  hidden_total=$(printf '%s\n' "$report" | /usr/bin/grep -Eo 'tests [0-9]+' | head -1 | cut -d' ' -f2)
  own_tests=$(cat "$workspace"/test/*.js "$workspace"/tests/*.js "$workspace"/test/*.mjs "$workspace"/tests/*.mjs "$workspace"/*.test.js "$workspace"/src/*.test.js 2>/dev/null | /usr/bin/grep -Ec '^\s*(test|it)\(')
  stop_blocks=$(/usr/bin/grep -o 'proof: you cannot finish yet' "$trace" 2>/dev/null | wc -l | tr -d ' ')
  denials=$(/usr/bin/grep -o 'PreToolUse:[A-Za-z]* hook error' "$trace" 2>/dev/null | wc -l | tr -d ' ')
  outcome=$(cat "$workspace/.proof/outcome" 2>/dev/null || printf -- '-')
  printf '%s#%s score=%s hidden=%s/%s ownTests=%s cost=$%.2f turns=%s secs=%s stopBlocks=%s denials=%s outcome=%s error=%s\n' \
    "$arm" "$run" "$score" "${hidden_pass:-0}" "${hidden_total:-21}" "$own_tests" "$cost" "$turns" "$seconds" "$stop_blocks" "$denials" "$outcome" "$error"
  printf '%s\n' "$report" | /usr/bin/grep '✖' | /usr/bin/grep -v 'failing tests' | sort -u | sed 's/^/    /' | head -8
done
