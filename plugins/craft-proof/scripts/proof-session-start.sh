#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq
source "$(dirname "$0")/proof-lib.sh"
proof_active || exit 0

exclude_contract_from_git() {
  local exclude
  exclude=$(git -C "$ROOT" rev-parse --git-path info/exclude 2>/dev/null) || return 0
  case "$exclude" in /*) ;; *) exclude="$ROOT/$exclude" ;; esac
  mkdir -p "$(dirname "$exclude")"
  "$GREP" -qx '.proof/' "$exclude" 2>/dev/null || printf '.proof/\n' >> "$exclude"
}

session_source=$(input_field .source)
notice=""
is_git && exclude_contract_from_git

if [ "$session_source" = startup ] || [ "$session_source" = clear ]; then
  if is_locked || [ -f "$WORK_CONTRACT" ]; then
    previous=$(cat "$OUTCOME" 2>/dev/null || printf 'unfinished')
    kept_deliverables=$(cat "$DELIVERABLES" 2>/dev/null || true)
    archive_task
    if [ "$previous" = proven ]; then
      take_baseline
    else
      [ -n "$kept_deliverables" ] && printf '%s\n' "$kept_deliverables" > "$DELIVERABLES"
      notice="proof: the previous task's contract was $previous and has been archived. Its changes still count, so the next contract must cover them or name them as unverified."
    fi
  else
    take_baseline
  fi
fi
[ -f "$BASELINE" ] || take_baseline

context="The craft-proof plugin is active in this folder. Before you change code or write a deliverable, write a contract. Before you finish, every claim in it must be proven on the final content: checks by the hooks recording the commands you run, and sources, calculations, files and rubrics by re-checking them when you finish.
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
