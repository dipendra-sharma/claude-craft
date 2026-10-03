#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq
source "$(dirname "$0")/proof-lib.sh"
is_git || exit 0

exclude_contract_from_git() {
  local exclude
  exclude=$(git -C "$ROOT" rev-parse --git-path info/exclude 2>/dev/null) || return 0
  case "$exclude" in /*) ;; *) exclude="$ROOT/$exclude" ;; esac
  mkdir -p "$(dirname "$exclude")"
  "$GREP" -qx '.proof/' "$exclude" 2>/dev/null || printf '.proof/\n' >> "$exclude"
}

session_source=$(input_field .source)
notice=""
mkdir -p "$STATE"
exclude_contract_from_git

if [ "$session_source" = startup ] || [ "$session_source" = clear ]; then
  if is_locked || [ -f "$WORK_CONTRACT" ]; then
    previous=$(cat "$OUTCOME" 2>/dev/null || printf 'unfinished')
    archive_task
    if [ "$previous" = proven ]; then
      take_baseline
    else
      notice="proof: the previous task's contract was $previous and has been archived. Its code changes still count as changed, so the next contract must cover them or name them as unverified."
    fi
  else
    take_baseline
  fi
fi
[ -f "$BASELINE" ] || take_baseline

context="The craft-proof plugin is active in this project. Before you change code, write a contract. Before you finish, every claim in it must have passing proof on the current code, recorded by hooks when you run its check.
$CONTRACT_GUIDE"
[ -n "$notice" ] && context="$context

$notice"

contract=$(active_contract)
if contract_valid_file "$contract"; then
  context="$context

Active contract:
$(cat "$contract")

Claim status (id, state, check):
$(claim_states "$contract" "$(snapshot)")"
fi

"$JQ" -n --arg c "$context" --arg m "$notice" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}} + (if $m != "" then {systemMessage: $m} else {} end)'
